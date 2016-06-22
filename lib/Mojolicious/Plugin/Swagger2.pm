package Mojolicious::Plugin::Swagger2;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::JSON;
use Mojo::Loader;
use Mojo::Util 'decamelize';
use Swagger2;
use JSON::Validator::OpenAPI;
use constant DEBUG      => $ENV{SWAGGER2_DEBUG};
use constant IO_LOGGING => $ENV{SWAGGER2_IO_LOGGING};    # EXPERIMENTAL

my $SKIP_OP_RE = qr(By|From|For|In|Of|To|With);
my $LAYOUT = Mojo::Loader::data_section(__PACKAGE__, 'layouts/mojolicious_plugin_swagger.html.ep');

has url => '';
has _validator => sub { JSON::Validator::OpenAPI->new; };

sub dispatch_to_swagger {
  return undef unless $_[1]->{op} and $_[1]->{id} and ref $_[1]->{params} eq 'HASH';

  my ($c, $data) = @_;
  my $self = $c->stash('swagger.plugin');
  my $reply
    = sub { $_[0]->send({json => {code => $_[2] || 200, id => $data->{id}, body => $_[1]}}) };
  my $defaults = $self->{route_defaults}{$data->{op}}
    or return $c->$reply(_error('Unknown operationId.'), 400);
  my ($e, $input, @errors);

  return $c->$reply(_error($e), 501) if $e = _find_action($c, $defaults);

  for my $p (@{$defaults->{swagger_operation_spec}{parameters} || []}) {
    my $name  = $p->{name};
    my $value = $data->{params}{$name} // $p->{default};
    my @e     = $self->_validator->_validate_request_value($p, $name => $value);
    $input->{$name} = $value unless @e;
    push @errors, @e;
  }

  return $c->$reply({errors => \@errors}, 400) if @errors;
  return Mojo::IOLoop->delay(
    sub {
      my $delay  = shift;
      my $action = $defaults->{action};
      my $sc     = $delay->data->{sc} = $defaults->{controller}->new(%$c);
      $sc->stash(swagger_operation_spec => $defaults->{swagger_operation_spec});
      $sc->$action($input, $delay->begin);
    },
    sub {
      my $delay  = shift;
      my $data   = shift;
      my $status = shift || 200;
      my @errors = $self->_validator->validate_response($c, $defaults->{swagger_operation_spec},
        $status, $data);

      return $c->$reply($data, $status) unless @errors;
      warn "[Swagger2] Invalid response: @errors\n" if DEBUG;
      $c->$reply({errors => \@errors}, 500);
    },
  );
}

sub render_swagger {
  my ($c, $err, $data, $status) = @_;

  return $c->render(json => $err, status => $status) if %$err;
  return $c->render(ref $data ? (json => $data) : (text => $data), status => $status);
}

sub register {
  my ($self, $app, $config) = @_;
  my ($base_path, $paths, $r, $swagger);

  $swagger = $config->{swagger} || Swagger2->new->load($config->{url} || '"url" is missing');
  $swagger = $swagger->expand;
  $paths   = $swagger->api_spec->get('/paths') || {};

  $app->plugin(PODRenderer => {no_perldoc => 1}) unless $app->renderer->helpers->{pod_to_html};

  if ($config->{validate} // 1) {
    my @errors = $swagger->validate;
    die join "\n", "Swagger2: Invalid spec:", @errors if @errors;
  }

  if ($app->plugins->has_subscribers('swagger_route_added')) {
    warn
      "swagger_route_added hook will be deprecated. https://github.com/jhthorsen/swagger2/issues/65";
  }
  else {
    $app->hook(swagger_route_added => \&_on_route_added);
  }

  local $config->{coerce} = $config->{coerce} || $ENV{SWAGGER_COERCE_VALUES};
  $self->_validator->coerce($config->{coerce}) if $config->{coerce};
  $self->_validator->schema($swagger->api_spec->data);
  $self->url($swagger->url);
  $app->helper(dispatch_to_swagger => \&dispatch_to_swagger)
    unless $app->renderer->get_helper('dispatch_to_swagger');
  $app->helper(render_swagger => \&render_swagger)
    unless $app->renderer->get_helper('render_swagger');

  $r = $config->{route};

  if ($r and !$r->pattern->unparsed) {
    $r->to(swagger => $swagger);
    $r = $r->any($swagger->base_url->path->to_string);
  }
  if (!$r) {
    $r = $app->routes->any($swagger->base_url->path->to_string);
    $r->to(swagger => $swagger);
  }
  if (my $ws = $config->{ws}) {
    $ws->to('swagger.plugin' => $self);
  }

  $base_path = $swagger->api_spec->data->{basePath} = $r->to_string;
  $base_path =~ s!/$!!;

  for my $path (sort { length $a <=> length $b } keys %$paths) {
    my $around_action
      = $paths->{$path}{'x-mojo-around-action'} || $swagger->api_spec->get('/x-mojo-around-action');
    my $controller
      = $paths->{$path}{'x-mojo-controller'} || $swagger->api_spec->get('/x-mojo-controller');

    for my $http_method (grep { !/^x-/ } keys %{$paths->{$path}}) {
      my $op_spec    = $paths->{$path}{$http_method};
      my $route_path = $path;
      my %parameters = map { ($_->{name}, $_) } @{$op_spec->{parameters} || []};

      $route_path =~ s/{([^}]+)}/{
        my $name = $1;
        my $type = $parameters{$name}{'x-mojo-placeholder'} || ':';
        "($type$name)";
      }/ge;

      $op_spec->{'x-mojo-around-action'} = $around_action
        if !$op_spec->{'x-mojo-around-action'} and $around_action;
      $op_spec->{'x-mojo-controller'} = $controller
        if !$op_spec->{'x-mojo-controller'} and $controller;
      $app->plugins->emit(swagger_route_added =>
          $r->$http_method($route_path => $self->_generate_request_handler($op_spec)));
      warn "[Swagger2] Add route $http_method $base_path$route_path\n" if DEBUG;
    }
  }

  if (my $spec_path = $config->{spec_path} // '/') {
    my $title = $swagger->api_spec->get('/info/title');
    $title =~ s!\W!_!g;
    $r->get($spec_path)->to(cb => sub { _render_spec(shift, $swagger) })->name(lc $title);
  }
  if ($config->{ensure_swagger_response}) {
    $self->_ensure_swagger_response($app, $config->{ensure_swagger_response}, $swagger);
  }
}

sub _ensure_swagger_response {
  my ($self, $app, $responses, $swagger) = @_;
  my $base_path = $swagger->api_spec->data->{basePath};

  $responses->{exception} ||= 'Internal server error.';
  $responses->{not_found} ||= 'Not found.';
  $base_path = qr{^$base_path};

  $app->hook(
    before_render => sub {
      my ($c, $args) = @_;

      return unless my $template = $args->{template};
      return unless my $msg      = $responses->{$template};
      return unless $c->req->url->path->to_string =~ $base_path;

      $args->{json} = _error($msg);
    }
  );
}

sub _generate_request_handler {
  my ($self, $op_spec) = @_;
  my $defaults = {swagger_operation_spec => $op_spec};

  my $handler = sub {
    my $c = shift;
    my ($e, @errors, %input);

    return $c->render_swagger(_error($e), {}, 501) if $e = _find_action($c, $defaults);
    $c = $defaults->{controller}->new(%$c);
    @errors = $self->_validator->validate_request($c, $op_spec, \%input);

    _io_error($c, Input => \@errors) if IO_LOGGING and @errors;
    return $c->render_swagger({errors => \@errors}, {}, 400) if @errors;
    return $c->delay(
      sub {
        my $action = $defaults->{action};
        $c->app->log->debug(
          qq(Swagger2 routing to controller "$defaults->{controller}" and action "$action"));
        $c->$action(\%input, shift->begin);
      },
      sub {
        my $delay  = shift;
        my $data   = shift;
        my $status = shift || 200;
        my @errors = $self->_validator->validate_response($c, $op_spec, $status, $data);

        return $c->render_swagger({}, $data, $status) unless @errors;
        _io_error($c, Output => \@errors) if IO_LOGGING and @errors;
        $c->render_swagger({errors => \@errors}, $data, 500);
      },
    );
  };

  for my $p (@{$op_spec->{parameters} || []}) {
    $defaults->{$p->{name}} = $p->{default} if $p->{in} eq 'path' and defined $p->{default};
  }

  if (my $around_action = $op_spec->{'x-mojo-around-action'}) {
    my $next = $handler;
    $handler = sub {
      my $c = shift;
      my $around = $c->can($around_action) || $around_action;
      $around->($next, $c, $op_spec);
    };
  }

  $self->{route_defaults}{$op_spec->{operationId}} = $defaults;
  return $defaults, $handler;
}

sub _on_route_added {
  my ($self, $r) = @_;
  my $op_spec    = $r->pattern->defaults->{swagger_operation_spec};
  my $controller = $op_spec->{'x-mojo-controller'};
  my $route_name;

  $route_name = $controller
    ? decamelize join '::', map { ucfirst $_ } $controller, $op_spec->{operationId}
    : decamelize $op_spec->{operationId};

  $route_name =~ s/\W+/_/g;
  $r->name($route_name);
}

sub _render_spec {
  my ($c, $swagger) = @_;
  my $format = $c->stash('format') || 'json';
  my $spec   = $swagger->api_spec->data;
  my $url    = $c->req->url->to_abs;

  local $spec->{id};
  delete $spec->{id};
  local $spec->{host} = $url->host_port;
  $swagger->base_url->host($url->host)->port($url->port);

  if ($format eq 'text') {
    $c->render(text => $swagger->pod->to_string);
  }
  elsif ($format eq 'html') {
    $c->render(
      handler => 'ep',
      inline  => $LAYOUT,
      pod     => $c->pod_to_html($swagger->pod->to_string)
    );
  }
  else {
    $c->render(json => $spec);
  }
}

sub _error {
  return {errors => [{message => $_[0], path => '/'}]};
}

sub _find_action {
  return if $_[1]->{controller};    # cached
  my ($c, $defaults) = @_;
  my $op = $defaults->{swagger_operation_spec}{operationId} or return 'operationId is missing.';
  my $can = sub {
    $defaults->{controller}->can($defaults->{action})
      ? ''
      : qq(Method "$defaults->{action}" not implemented.);
  };

  # specify controller manually
  @$defaults{qw(action controller)}
    = _load($c, $op, $defaults->{swagger_operation_spec}{'x-mojo-controller'});
  return $can->() if $defaults->{controller};

  # "createFileInFileSystem" = ("createFile", "FileSystem")
  @$defaults{qw(action controller)} = _load($c, split $SKIP_OP_RE, $op);
  return $can->() if $defaults->{controller};

  # "showPetById" = "showPet"
  $op =~ s!$SKIP_OP_RE.*$!!;

  # "show_fooPet" = ("show_foo", "Pet")
  @$defaults{qw(action controller)} = _load($c, $op =~ /^([a-z_]+)([A-Z]\w+)$/);
  return $can->() if $defaults->{controller};

  return
    qq(Controller from operationId "$defaults->{swagger_operation_spec}{operationId}" could not be loaded.);
}

sub _io_error {
  my $c     = shift;
  my $level = IO_LOGGING;
  $c->app->log->$level(sprintf '%s error: %s', shift, Mojo::JSON::encode_json(shift));
}

sub _load {
  my ($c, $action, $controller) = @_;
  my (@classes, %uniq);

  return unless $controller;
  $action = decamelize ucfirst $action;

  if ($controller =~ /::/) {
    push @classes, $controller;
  }
  else {
    my $singular = $controller;
    $singular =~ s!s$!!;    # "showPets" = "showPet"
    push @classes,
      grep { !$uniq{$_}++ }
      map { ("${_}::$controller", "${_}::$singular") } @{$c->app->routes->namespaces};
  }

  while ($controller = shift @classes) {
    my $e = Mojo::Loader::load_class($controller);
    warn
      qq([Swagger2] Load "$controller": @{[ref $e ? $e : $e ? "Can't locate class" : "Success"]}.\n)
      if DEBUG;
    return ($action, $controller) if $controller->can('new');
  }

  return;
}

1;

=encoding utf8

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

=item * L<Swagger2::Guides::JSONSchemaSupport> - Adding json-schema support - EXPERIMENTAL

=item * L<Swagger spec|https://github.com/jhthorsen/swagger2/blob/master/t/blog/api.json>

=item * L<Application|https://github.com/jhthorsen/swagger2/blob/master/t/blog/lib/Blog.pm>

=item * L<Controller|https://github.com/jhthorsen/swagger2/blob/master/t/blog/lib/Blog/Controller/Posts.pm>

=item * L<Tests|https://github.com/jhthorsen/swagger2/blob/master/t/authenticate.t>

=back

=head1 HOOKS

=head2 swagger_route_added

This hook will be DEPRECATED! See L<https://github.com/jhthorsen/swagger2/issues/65>.

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

=head1 ATTRIBUTES

=head2 url

Holds the URL to the swagger specification file.

=head1 HELPERS

=head2 dispatch_to_swagger

  $bool = $c->dispatch_to_swagger(\%data);

This helper can be used to handle WebSocket requests with swagger.
See L<Swagger2::Guides::WebSocket> for details.

This helper is EXPERIMENTAL.

=head2 render_swagger

  $c->render_swagger(\%err, \%data, $status);

This method is used to render C<%data> from the controller method. The C<%err>
hash will be empty on success, but can contain input/output validation errors.
C<$status> is used to set a proper HTTP status code such as 200, 400 or 500.

See also L<Swagger2::Guides::Render> for more information.

=head1 METHODS

=head2 register

  $self->register($app, \%config);

This method is called when this plugin is registered in the L<Mojolicious>
application.

C<%config> can contain these parameters:

=over 4

=item * coerce

This argument will be passed on to L<JSON::Validator/coerce>.

=item * ensure_swagger_response

  $app->plugin(swagger2 => {
    ensure_swagger_response => {
      exception => "Internal server error.",
      not_found => "Not found.",
    }
  });

Adds a L<before_render|Mojolicious/HOOKS> hook which will make sure
"exception" and "not_found" responses are in JSON format. There is no need to
specify "exception" and "not_found" if you are happy with the defaults.

=item * route

Need to hold a Mojolicious route object. See L</Protected API> for an example.

This parameter is optional.

=item * spec_path

Holds the location for where the specifiation can be served from. The default
value is "/", relative to "basePath" in the specification. Can be disabled
by setting this value to empty string.

=item * validate

A boolean value (default is true) that will cause your schema to be validated.
This plugin will abort loading if the schema include errors

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

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014-2015, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

__DATA__
@@ layouts/mojolicious_plugin_swagger.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= $swagger->api_spec->get('/info/title') %></title>
    <style>
      body {
        background: #fefefe;
        font-family: sans-serif;
        font-size: 16px;
      }
      pre {
        background: #f4f4f4;
        border: 1px solid #ddd;
        padding: 5px;
      }
      .container {
        max-width: 60em;
        margin: 3em auto;
      }
    </style>
  </head>
  <body>
    <div class="container">
      <%= $pod %>
    </div>
  </body>
</html>
