package Mojolicious::Plugin::Swagger2;

=head1 NAME

Mojolicious::Plugin::Swagger2 - Mojolicious plugin for Swagger2

=head1 DESCRIPTION

L<Mojolicious::Plugin::Swagger2> is L<Mojolicious::Plugin> that add routes and
input/output validation to your L<Mojolicious> application.

=head2 Limitations

=over 4

=item * Only JSON

Currently this plugin can only exchange JSON data. Pull requests are
more than welcome to fix this.

=item * Fixed 501 response

The server will respond with "501 Not Implemented", unless the L</controller>
has defined the requested method. The JSON response is also fixed (for now):

  {
    "valid": false,
    "errors": [
      {
        "message": "No handler defined.",
        "property": null
      }
    ]
  }

Note: The "message" might change.

=back

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
will receive the current L<Mojolicious::Controller> object and a callback.
The callback should be called with a HTTP status code, and a data structure
which will be validated and serialized back to the user agent.

  package MyApp::Controller::Api;

  sub list_pets_get {
    my ($c, $cb) = @_;
    $c->$cb(200 => { foo => 123 });
  }

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Util 'decamelize';
use Swagger2::SchemaValidator;
use Swagger2;
use constant DEBUG => $ENV{SWAGGER2_DEBUG} || 0;

=head1 ATTRIBUTES

=head2 controller

Holds a class name, which is used to dispatch the request to.

=head2 default_code

The default HTTP code, if everything fails. This is set to 500 by default.

=head2 url

Holds the URL to the swagger specification file.

=cut

has controller   => '';
has default_code => 500;
has url          => '';

has _validator => sub {
  Swagger2::SchemaValidator->new;
};

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
  for my $k (qw( default_code )) {
    $config->{$k} or next;
    $self->$k($config->{$k});
  }

  eval "require $self->{controller}; 1" or die "Could not load controller $self->{controller}: $@";

  $swagger   = Swagger2->new->load($self->url)->expand;
  $base_path = $swagger->base_url->path;
  $paths     = $swagger->tree->get('/paths') || {};

  for my $path (keys %$paths) {
    my $route_path = '/' . join '/', grep {$_} @$base_path, split '/', $path;

    for my $method (keys %{$paths->{$path}}) {
      my $m    = lc $method;
      my $info = $paths->{$path}{$method};
      my $name = decamelize(ucfirst sprintf '%s_%s', $info->{operationId} || $route_path, $m);
      die "$name is not an unique route! ($method $path)" if $app->routes->lookup($name);
      warn "[Swagger2] Add route $method $route_path\n"   if DEBUG;
      $r->$m($route_path => sub { $self->_handle_request($_[0], $name, $info); })->name($name);
    }
  }
}

sub _handle_request {
  my ($self, $c, $method, $config) = @_;

  # ugly hack?
  bless $c, $self->controller;

  unless ($c->can($method)) {
    return $c->render(json => $self->_not_implemented, status => 501);
  }

  $c->stash(swagger_config => $config);
  $c->delay(
    sub {
      my $delay = shift;
      $c->$method($delay->begin);
    },
    sub {
      my $delay = shift;
      $self->_render($c, @_);
    },
  );
}

sub _not_implemented {
  {valid => Mojo::JSON->false, errors => [{message => 'No handler defined.', property => undef}]};
}

sub _render {
  my ($self, $c, $status, $data) = @_;
  my $config = $c->stash('swagger_config');
  my $format = $config->{responses}{$status} || $config->{responses}{default};
  my $res;

  unless ($format) {
    return $c->render_exception("Status code ($status) is not defined in Swagger specification");
  }

  $res = $self->_validator->validate($data, $format->{schema});
  $status = $self->default_code if $status eq 'default';

  return $c->render(json => $res, status => 500) unless $res->{valid};
  return $c->render(json => $data, status => $status);
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
