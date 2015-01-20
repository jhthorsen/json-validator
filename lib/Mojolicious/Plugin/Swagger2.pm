package Mojolicious::Plugin::Swagger2;

=head1 NAME

Mojolicious::Plugin::Swagger2 - Mojolicious plugin for Swagger2

=head1 DESCRIPTION

L<Mojolicious::Plugin::Swagger2> is L<Mojolicious::Plugin> that add routes and
input/output validation to your L<Mojolicious> application.

=head1 SYNOPSIS

=head2 Swagger specification

The input L</url> to given as argument to the plugin need to point to a
valid L<swagger|https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md>
document.

Note that every operation must have a "x-mojo-controller" specified,
so this plugin knows where to look for the decamelized "operationId",
which is used as method name.

  ---
  swagger: 2.0
  basePath: /api
  paths:
    /foo:
      get:
        x-mojo-controller: MyApp::Controller::Api
        operationId: listPets
        parameters: [ ... ]
        responses:
          200: { ... }

=head2 Application

The application need to load the L<Mojolicious::Plugin::Swagger2> plugin,
with a URL to the API specification. The plugin will then add all the routes
defined in the L</Swagger specification>.

  use Mojolicious::Lite;
  plugin Swagger2 => { url => app->home->rel_file("api.yaml") };
  app->start;

=head2 Controller

The method names defined in the controller will be a
L<decamelized|Mojo::Util::decamelize> version of C<operationId>.

The example L</Swagger specification> above, will result in
C<list_pets()> in the controller below to be called. This method
will receive the current L<Mojolicious::Controller> object, input arguments
and a callback. The callback should be called with a HTTP status code, and
a data structure which will be validated and serialized back to the user
agent.

  package MyApp::Controller::Api;

  sub list_pets {
    my ($c, $args, $cb) = @_;
    $c->$cb({ foo => 123 }, 200);
  }

=head2 Protected API

It is possible to protect your API, using a custom route:

  use Mojolicious::Lite;

  my $route = app->routes->under->to(
    cb => sub {
      my $c = shift;
      return 1 if $c->param('secret');
      return $c->render(json => {error => "Not authenticated"}, status => 401);
    }
  );

  plugin Swagger2 => {
    route => $route,
    url   => app->home->rel_file("api.yaml")
  };

=head2 Custom placeholders

The default placeholder type is the
L<generic placeholder|https://metacpan.org/pod/distribution/Mojolicious/lib/Mojolicious/Guides/Routing.pod#Generic-placeholders>,
meaning ":". This can be customized using C<x-mojo-placeholder> in the
API specification. The example below will enforce a
L<relaxed placeholder|https://metacpan.org/pod/distribution/Mojolicious/lib/Mojolicious/Guides/Routing.pod#Relaxed-placeholders>:

  ---
  swagger: 2.0
  basePath: /api
  paths:
    /foo:
      get:
        x-mojo-controller: MyApp::Controller::Api
        operationId: listPets
        parameters:
        - name: ip
          in: path
          type: string
          x-mojo-placeholder: "#"
        responses:
          200: { ... }

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::JSON;
use Mojo::Util 'decamelize';
use Swagger2::SchemaValidator;
use Swagger2;
use constant DEBUG => $ENV{SWAGGER2_DEBUG} || 0;

=head1 ATTRIBUTES

=head2 url

Holds the URL to the swagger specification file.

=cut

has url => '';
has _validator => sub { Swagger2::SchemaValidator->new; };

=head1 HELPERS

=head2 render_swagger

  $c->render_swagger(\%err, \%data, $status);

This method is used to render C<%data> from the controller method. The C<%err>
hash will be empty on success, but can contain input/output validation errors.
C<$status> is the HTTP status code to use:

=over 4

=item * 200

The default C<$status> is 200, unless the method handling the request sent back
another value. C<%err> will be empty in this case.

=item * 400

This module will set C<$status> to 400 on invalid input. C<%err> then contains
a data structure describing the errors. The default is to render a JSON
document, like this:

  {
    "valid": false,
    "errors": [
      {
        "message": "string value found, but a integer is required",
        "path": "/limit"
      },
      ...
    ]
  }

=item * 500

This module will set C<$status> to 500 on invalid response from the handler.
C<%err> then contains a data structure describing the errors. The default is
to render a JSON document, like this:

  {
    "valid": false,
    "errors": [
      {
        "message": "is missing and it is required",
        "path": "/foo"
      },
      ...
    ]
  }

=item * 501

This module will set C<$status> to 501 if the given controller has not
implemented the required method. C<%err> then contains a data structure
describing the errors. The default is to render a JSON document, like this:

  {
    "valid": false,
    "errors": [
      {
        "message": "No handler defined.",
        "path": "/"
      }
    ]
  }

=back

=cut

sub render_swagger {
  my ($c, $err, $data, $status) = @_;

  return $c->render(json => $err, status => $status) if %$err;
  return $c->render(ref $data ? (json => $data) : (text => $data), status => $status);
}

=head1 METHODS

=head2 register

  $self->register($app, \%config);

This method is called when this plugin is registered in the L<Mojolicious>
application.

=cut

sub register {
  my ($self, $app, $config) = @_;
  my $r = $config->{route} || $app->routes->any('/');
  my ($base_path, $paths, $swagger);

  $self->url($config->{url} || die "'url' is required config parameter");
  $self->{controller} = $config->{controller};    # back compat
  $app->helper(render_swagger => \&render_swagger);

  $swagger   = Swagger2->new->load($self->url)->expand;
  $base_path = $swagger->base_url->path;
  $paths     = $swagger->tree->get('/paths') || {};

  for my $path (keys %$paths) {
    for my $http_method (keys %{$paths->{$path}}) {
      my $info       = $paths->{$path}{$http_method};
      my $route_path = '/' . join '/', grep {$_} @$base_path, split '/', $path;
      my %parameters = map { ($_->{name}, $_) } @{$info->{parameters} || []};

      $route_path =~ s/{([^}]+)}/{
        my $name = $1;
        my $type = $parameters{$name}{'x-mojo-placeholder'} || ':';
        "($type$name)";
      }/ge;

      my $name = decamelize(ucfirst $info->{operationId} || $route_path);
      die "$name is not a unique route! ($http_method $path)" if $app->routes->lookup($name);
      warn "[Swagger2] Add route $http_method $route_path\n"  if DEBUG;
      $r->$http_method($route_path => $self->_generate_request_handler($name, $info))->name($name);
    }
  }
}

sub _generate_request_handler {
  my ($self, $method, $config) = @_;
  my $controller = $config->{'x-mojo-controller'} || $self->{controller};    # back compat

  return sub {
    my $c = shift;
    my $method_ref;

    unless (eval "require $controller;1") {
      $c->app->log->error($@);
      return $c->render_swagger($self->_not_implemented('Controller not implemented.'), {}, 501);
    }
    unless ($method_ref = $controller->can($method)) {
      $method_ref = $controller->can(sprintf '%s_%s', $method, lc $c->req->method)
        and warn "HTTP method name is not used in method name lookup anymore!";
    }
    unless ($method_ref) {
      $c->app->log->error(
        qq(Can't locate object method "$method" via package "$controller. (Something is wrong in @{[$self->url]})"));
      return $c->render_swagger($self->_not_implemented('Method not implemented.'), {}, 501);
    }

    bless $c, $controller;    # ugly hack?

    $c->delay(
      sub {
        my ($delay) = @_;
        my ($v, $input) = $self->_validate_input($c, $config);

        return $c->render_swagger($v, {}, 400) unless $v->{valid};
        return $c->$method_ref($input, $delay->begin);
      },
      sub {
        my $delay  = shift;
        my $data   = shift;
        my $status = shift || 200;
        my $format = $config->{responses}{$status} || $config->{responses}{default} || {};
        my @err    = $self->_validator->validate($data, $format->{schema});

        return $c->render_swagger({errors => \@err, valid => Mojo::JSON->false}, $data, 500) if @err;
        return $c->render_swagger({}, $data, $status);
      },
    );
  };
}

sub _not_implemented {
  my ($self, $message) = @_;
  return {valid => Mojo::JSON->false, errors => [{message => $message, path => '/'}]};
}

sub _validate_input {
  my ($self, $c, $config) = @_;
  my $headers = $c->req->headers;
  my $query   = $c->req->url->query;
  my (%input, %v);

  for my $p (@{$config->{parameters} || []}) {
    my ($in, $name) = @$p{qw( in name )};
    my ($value, @e);

    $value
      = $in eq 'query'    ? $query->param($name)
      : $in eq 'path'     ? $c->stash($name)
      : $in eq 'header'   ? $headers->header($name)
      : $in eq 'body'     ? $c->req->json
      : $in eq 'formData' ? $c->req->body_params->to_hash
      :                     "Invalid 'in' for parameter $name in schema definition";

    if (defined $value or $p->{required}) {
      my $type = $p->{type} || 'object';
      $value += 0 if $type =~ /^(?:integer|number)/ and $value =~ /^\d/;
      $value = ($value eq 'false' or !$value) ? Mojo::JSON->false : Mojo::JSON->true if $type eq 'boolean';

      if ($in eq 'body' or $in eq 'formData') {
        warn "[Swagger2] Validate $in @{[$c->req->body]}\n" if DEBUG;
        push @e, map { $_->{path} = "/$name$_->{path}"; $_; } $self->_validator->validate($value, $p->{schema});
      }
      else {
        warn "[Swagger2] Validate $in $name=$value\n" if DEBUG;
        push @e, $self->_validator->validate({$name => $value}, {properties => {$name => $p}});
      }
    }

    $input{$name} = $value unless @e;
    push @{$v{errors}}, @e;
  }

  $v{valid} = @{$v{errors} || []} ? Mojo::JSON->false : Mojo::JSON->true;
  return \%v, \%input;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
