package Mojolicious::Plugin::Swagger2;

=head1 NAME

Mojolicious::Plugin::Swagger2 - Mojolicious plugin for Swagger2

=head1 SYNOPSIS

  package MyApp;
  use Mojo::Base "Mojolicious";

  sub startup {
    my $app = shift;
    $app->plugin(Swagger2 => {url => "data://MyApp/petstore.json"});
  }

  __DATA__
  @@ petstore.json
  {
    "swagger": "2.0",
    "info": {...},
    "host": "petstore.swagger.wordnik.com",
    "basePath": "/api",
    "paths": {
      "/pets": {
        "get": {...}
      }
    }
  }

=head1 DESCRIPTION

L<Mojolicious::Plugin::Swagger2> is L<Mojolicious::Plugin> that add routes and
input/output validation to your L<Mojolicious> application.

Have a look at the L</RESOURCES> for a complete reference to what is possible
or look at L<Swagger2::Guides::Tutorial> for an introduction.

=head1 RESOURCES

=over 4

=item * L<Swagger2::Guides::Tutorial> - Tutorial for this plugin

=item * L<Swagger2::Guides::Render> - Details about the render process

=item * L<Swagger2::Guides::ProtectedApi> - Protected API Guide

=item * L<Swagger2::Guides::CustomPlaceholder> - Custom placeholder for your routes

=item * L<Swagger spec|https://github.com/jhthorsen/swagger2/blob/master/t/blog/api.json>

=item * L<Application|https://github.com/jhthorsen/swagger2/blob/master/t/blog/lib/Blog.pm>

=item * L<Controller|https://github.com/jhthorsen/swagger2/blob/master/t/blog/lib/Blog/Controller/Posts.pm>

=item * L<Tests|https://github.com/jhthorsen/swagger2/blob/master/t/authenticate.t>

=back

=head1 STASH VARIABLES

=head2 swagger

The L<Swagger2> object used to generate the routes is available
as C<swagger> from L<stash|Mojolicious/stash>. Example code:

  sub documentation {
    my ($c, $args, $cb);
    $c->$cb($c->stash('swagger')->pod->to_string, 200);
  }

=head2 swagger_operation_spec

The Swagger specification for the current
L<operation object|https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md#operationObject>
is stored in the "swagger_operation_spec" stash variable.

  sub list_pets {
    my ($c, $args, $cb);
    $c->app->log->info($c->stash("swagger_operation_spec")->{operationId});
    ...
  }

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::JSON;
use Mojo::Util 'decamelize';
use Swagger2;
use Swagger2::SchemaValidator;
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
C<$status> is used to set a proper HTTP status code such as 200, 400 or 500.

See also L<Swagger2::Guides::Render> for more information.

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

C<%config> can contain these parameters:

=over 4

=item * coerce

This argument will be passed on to L<JSON::Validator/coerce>.

=item * route

Need to hold a Mojolicious route object. See L</Protected API> for an example.

This parameter is optional.

=item * validate

A boolean value (default is true) that will cause your schema to be validated.
This plugin will abort loading if the schema include errors

CAVEAT! There is an issue with YAML and booleans, so YAML specs might fail
even when they are correct. See L<https://github.com/jhthorsen/swagger2/issues/39>.

=item * swagger

A C<Swagger2> object. This can be useful if you want to keep use the
specification to other things in your application. Example:

  use Swagger2;
  my $swagger = Swagger2->new->load($url);
  plugin Swagger2 => {swagger => $swagger2};
  app->defaults(swagger_spec => $swagger->api_spec);

Either this parameter or C<url> need to be present.

=item * url

This will be used to construct a new L<Swagger2> object. The C<url>
can be anything that L<Swagger2/load> can handle.

Either this parameter or C<swagger> need to be present.

=back

=cut

sub register {
  my ($self, $app, $config) = @_;
  my ($paths, $r, $swagger);

  $swagger = $config->{swagger} || Swagger2->new->load($config->{url} || '"url" is missing');
  $swagger = $swagger->expand;
  $paths   = $swagger->api_spec->get('/paths') || {};

  if ($config->{validate} // 1) {
    my @errors = $swagger->validate;
    die join "\n", "Swagger2: Invalid spec:", @errors if @errors;
  }

  local $config->{coerce} = $config->{coerce} || $ENV{SWAGGER_COERCE_VALUES};
  $self->_validator->coerce($config->{coerce}) if $config->{coerce};
  $self->url($swagger->url);
  $app->helper(render_swagger => \&render_swagger) unless $app->renderer->get_helper('render_swagger');

  $r = $config->{route};

  if ($r and !$r->pattern->unparsed) {
    $r->to(swagger => $swagger);
    $r = $r->any($swagger->base_url->path->to_string);
  }
  if (!$r) {
    $r = $app->routes->any($swagger->base_url->path->to_string);
    $r->to(swagger => $swagger);
  }

  for my $path (sort { length $a <=> length $b } keys %$paths) {
    $paths->{$path}{'x-mojo-around-action'} ||= $swagger->api_spec->get('/x-mojo-around-action');
    $paths->{$path}{'x-mojo-controller'}    ||= $swagger->api_spec->get('/x-mojo-controller');

    for my $http_method (grep { !/^x-/ } keys %{$paths->{$path}}) {
      my $op_spec    = $paths->{$path}{$http_method};
      my $route_path = $path;
      my %parameters = map { ($_->{name}, $_) } @{$op_spec->{parameters} || []};
      my $route_name;

      $route_path =~ s/{([^}]+)}/{
        my $name = $1;
        my $type = $parameters{$name}{'x-mojo-placeholder'} || ':';
        "($type$name)";
      }/ge;

      $op_spec->{'x-mojo-around-action'} ||= $paths->{$path}{'x-mojo-around-action'};
      $op_spec->{'x-mojo-controller'}    ||= $paths->{$path}{'x-mojo-controller'};
      $route_name = decamelize(
        join '::',
        map { ucfirst $_ } $op_spec->{'x-mojo-controller'},
        ($op_spec->{operationId} || $route_path)
      );
      $route_name =~ s/\W+/_/g;
      $r->$http_method($route_path => $self->_generate_request_handler($route_path, $op_spec))->name($route_name);
      warn "[Swagger2] Add route $http_method $route_path ($route_name)\n" if DEBUG;
    }
  }
}

sub _generate_request_handler {
  my ($self, $route_path, $config) = @_;
  my $op         = $config->{operationId} || $route_path;
  my $method     = decamelize(ucfirst $op);
  my $controller = $config->{'x-mojo-controller'} or _die($config, "x-mojo-controller is missing in the swagger spec");
  my $defaults   = {swagger_operation_spec => $config};
  my $handler;

  $handler = sub {
    my $c = shift;
    my ($method_ref, $v, $input);

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
      return $c->render_swagger($self->_not_implemented(qq(Method "$op" not implemented.)), {}, 501);
    }

    bless $c, $controller;    # ugly hack?
    ($v, $input) = $self->_validate_input($c, $config);

    return $c->render_swagger($v, {}, 400) unless $v->{valid};
    return $c->delay(
      sub { $c->$method_ref($input, shift->begin); },
      sub {
        my $delay  = shift;
        my $data   = shift;
        my $status = shift || 200;
        my $format = $config->{responses}{$status} || $config->{responses}{default} || undef;
        my @err
          = !$format ? $self->_validator->validate($data, {})
          : $format->{schema} ? $self->_validator->validate($data, $format->{schema})
          :                     ();

        return $c->render_swagger({errors => \@err, valid => Mojo::JSON->false}, $data, 500) if @err;
        return $c->render_swagger({}, $data, $status);
      },
    );
  };

  for my $p (@{$config->{parameters} || []}) {
    $defaults->{$p->{name}} = $p->{default} if $p->{in} eq 'path' and defined $p->{default};
  }

  if (my $around_action = $config->{'x-mojo-around-action'}) {
    my $next = $handler;
    $handler = sub {
      my $c = shift;
      my $around = $c->can($around_action) || $around_action;
      $around->($next, $c, $config);
    };
  }

  return $defaults, $handler;
}

sub _not_implemented {
  my ($self, $message) = @_;
  return {valid => Mojo::JSON->false, errors => [{message => $message, path => '/'}]};
}

sub _validate_input {
  my ($self, $c, $config) = @_;
  my $body    = $c->req->body_params;
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
      : $in eq 'formData' ? $body->param($name)
      :                     "Invalid 'in' for parameter $name in schema definition";

    $value //= $p->{default};

    if (defined $value or Swagger2::_is_true($p->{required})) {
      my $type = $p->{type} || 'object';
      $value += 0 if $type =~ /^(?:integer|number)/ and $value =~ /^-?\d/;
      $value = ($value eq 'false' or !$value) ? Mojo::JSON->false : Mojo::JSON->true if $type eq 'boolean';

      my $schema = {properties => {$name => $p}, required => [$p->{required} ? ($p->{name}) : ()],};

      # ugly hack
      if (ref $p->{items} eq 'HASH' and $p->{items}{collectionFormat}) {
        $value = _coerce_by_collection_format($p->{items}, $value);
      }

      if ($in eq 'body') {
        warn "[Swagger2] Validate $in @{[$c->req->body]}\n" if DEBUG;
        push @e,
          map { $_->{path} = $_->{path} eq "/" ? "/$name" : "/$name$_->{path}"; $_; }
          $self->_validator->validate($value, $p->{schema});
      }
      elsif (defined $value) {
        warn "[Swagger2] Validate $in $name=$value\n" if DEBUG;
        push @e, $self->_validator->validate({$name => $value}, $schema);
      }
      else {
        warn "[Swagger2] Validate $in $name=undef()\n" if DEBUG;
        push @e, $self->_validator->validate({}, $schema);
      }
    }

    $input{$name} = $value unless @e;
    push @{$v{errors}}, @e;
  }

  $v{valid} = @{$v{errors} || []} ? Mojo::JSON->false : Mojo::JSON->true;
  return \%v, \%input;
}

# copy/paste from JSON::Validator
sub _coerce_by_collection_format {
  my ($schema, $data) = @_;
  my $format = $schema->{collectionFormat};
  my @data = $format eq 'ssv' ? split / /, $data : $format eq 'tsv' ? split /\t/,
    $data : $format eq 'pipes' ? split /\|/, $data : split /,/, $data;

  return [map { $_ + 0 } @data] if $schema->{type} and $schema->{type} =~ m!^(integer|number)$!;
  return \@data;
}

sub _die {
  die "$_[1]: ", Mojo::Util::dumper($_[0]);
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014-2015, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
