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

  ---
  swagger: 2.0
  basePath: /api
  paths:
    /foo:
      get:
        operationId: listPets
        parameters: [ ... ]
        responses:
          200: { ... }

=head2 Application

The application need to load the L<Mojolicious::Plugin::Swagger2> plugin,
with a URL to the specification and a controller namespace. The plugin
will then add all the routes defined in the L</Swagger specification>.

  use Mojolicious::Lite;

  plugin Swagger2 => {
    url => app->home->rel_file("api.yaml"),
    controller => "MyApp::Controller::Api",
  };

  app->start;

=head2 Controller

The method names defined in the controller will be a
L<decamelized|Mojo::Util::decamelize> version of C<operationId> with the
HTTP method at the end.

The example L</Swagger specification> above, will result in
C<list_pets_get()> in the controller below to be called. This method
will receive the current L<Mojolicious::Controller> object, input arguments
and a callback. The callback should be called with a HTTP status code, and
a data structure which will be validated and serialized back to the user
agent.

  package MyApp::Controller::Api;

  sub list_pets_get {
    my ($c, $args, $cb) = @_;
    $c->$cb({ foo => 123 }, 200);
  }

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::JSON;
use Mojo::Util 'decamelize';
use Swagger2::SchemaValidator;
use Swagger2;
use constant DEBUG => $ENV{SWAGGER2_DEBUG} || 0;

=head1 ATTRIBUTES

=head2 controller

Holds a class name, which is used to dispatch the request to.

=head2 url

Holds the URL to the swagger specification file.

=cut

has controller => '';
has url        => '';
has _validator => sub { Swagger2::SchemaValidator->new; };

=head1 HELPERS

=head2 render_swagger

  $c->render_swagger(\%err, \%data, $status);

This method is used to render C<%data> from the controller method. The C<%err>
hash will be empty on success, but can contain input/output validation errors.
C<$status> is the HTTP status code to use:

=over 4

=item * 200

The default C<$status> is 200, unless the controller sent back any value.
C<%err> will be empty in this case.

=item * 400

This module will set C<$status> to 400 on invalid input. C<%err> then contains
a data structure describing the errors. The default is to render a JSON
document, like this:

  {
    "valid": false,
    "errors": [
      {
        "message": "string value found, but a integer is required",
        "property": "$.limit"
      },
      ...
    ]
  }

=item * 500

This module will set C<$status> to 500 on invalid response from the controller.
C<%err> then contains a data structure describing the errors. The default is
to render a JSON document, like this:

  {
    "valid": false,
    "errors": [
      {
        "message": "is missing and it is required",
        "property": "$.foo"
      },
      ...
    ]
  }

=item * 501

This module will set C<$status> to 501 if the L</controller> has not implemented
the required method. C<%err> then contains a data structure describing the
errors. The default is to render a JSON document, like this:

  {
    "valid": false,
    "errors": [
      {
        "message": "No handler defined.",
        "property": null
      }
    ]
  }

=back

=cut

sub render_swagger {
  my ($c, $err, $data, $status) = @_;

  return $c->render(json => $err, status => $status) if %$err;
  return $c->render(json => $data, status => $status);
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

  for my $k (qw( controller url )) {
    $config->{$k} or die "'$k' is required config parameter";
    $self->$k($config->{$k});
  }

  $app->helper(render_swagger => \&render_swagger);

  eval "require $self->{controller}; 1" or die "Could not load controller $self->{controller}: $@";

  $swagger   = Swagger2->new->load($self->url)->expand;
  $base_path = $swagger->base_url->path;
  $paths     = $swagger->tree->get('/paths') || {};

  for my $path (keys %$paths) {
    my $route_path = '/' . join '/', grep {$_} @$base_path, split '/', $path;

    $route_path =~ s/{([^}]+)}/:$1/g;

    for my $method (keys %{$paths->{$path}}) {
      my $m    = lc $method;
      my $info = $paths->{$path}{$method};
      my $name = decamelize(ucfirst sprintf '%s_%s', $info->{operationId} || $route_path, $m);
      die "$name is not an unique route! ($method $path)" if $app->routes->lookup($name);
      warn "[Swagger2] Add route $method $route_path\n"   if DEBUG;
      $r->$m($route_path => $self->_generate_request_handler($name, $info))->name($name);
    }
  }
}

sub _generate_request_handler {
  my ($self, $method, $config) = @_;
  my $controller = $self->controller;

  unless ($controller->can($method)) {
    return sub { shift->render_swagger($self->_not_implemented, {}, 501) };
  }

  return sub {
    my $c = shift;
    bless $c, $controller;    # ugly hack?

    $c->delay(
      sub {
        my ($delay) = @_;
        my ($v, $input) = $self->_validate_input($c, $config);

        return $c->render_swagger($v, {}, 400) unless $v->{valid};
        return $c->$method($input, $delay->begin);
      },
      sub {
        my $delay  = shift;
        my $data   = shift;
        my $status = shift || 200;
        my $format = $config->{responses}{$status} || $config->{responses}{default};
        my @err    = $self->_validator->validate($data, $format->{schema});

        return $c->render_swagger({errors => \@err, valid => Mojo::JSON->false}, $data, 500) if @err;
        return $c->render_swagger({}, $data, $status);
      },
    );
  };
}

sub _not_implemented {
  {valid => Mojo::JSON->false, errors => [{message => 'No handler defined.', property => undef}]};
}

sub _validate_input {
  my ($self, $c, $config) = @_;
  my $headers = $c->req->headers;
  my $query   = $c->req->url->query;
  my $body    = $c->req->json || $c->req->body_params->to_hash || {};
  my (%input, %v);

  for my $p (@{$config->{parameters} || []}) {
    my @e;
    my $in   = $p->{in};
    my $name = $p->{name};
    my $value
      = $in eq 'query'  ? $query->param($name)
      : $in eq 'path'   ? $c->stash($name)
      : $in eq 'header' ? $headers->header($name)
      :                   $body->{$name} || $body;

    $p = $p->{schema} if $p->{schema} and $in !~ m(body|form);

    if (defined $value or $p->{required}) {
      $value += 0 if $p->{type} and $p->{type} =~ /^(?:integer|number)/ and $value =~ /^\d/;
      push @e, $self->_validator->validate({$name => $value}, {type => 'object', properties => {$name => $p}});
    }

    $input{$name} = $value unless @e;
    push @{$v{errors}}, @e;
  }

  $v{valid} = @{$v{errors}} ? Mojo::JSON->false : Mojo::JSON->true;
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
