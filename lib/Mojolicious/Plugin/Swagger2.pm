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

=head1 HOOKS

=head2 swagger_route_added

  $app->hook(swagger_route_added => sub {
    my ($app, $r) = @_;
    my $op_spec = $r->pattern->defaults->{swagger_operation_spec};
    # ...
  });

The "swagger_route_added" event will be emitted on the application object
for every route that is added by this plugin. This can be useful if you
want to do things like specifying a custom route name.

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
use Mojo::Loader 'load_class';
use Mojo::Util 'decamelize';
use Swagger2;
use Swagger2::SchemaValidator;
use constant DEBUG => $ENV{SWAGGER2_DEBUG} || 0;

my $SKIP_OP_RE = qr/(?:By|For|In|Of|To|With)?/;

=head1 ATTRIBUTES

=head2 url

Holds the URL to the swagger specification file.

=cut

has url => '';
has _validator => sub { Swagger2::SchemaValidator->new; };

=head1 HELPERS

=head2 dispatch_to_swagger

  $bool = $c->dispatch_to_swagger(\%data);

This helper can be used to handle WebSocket requests with swagger.
See L<Swagger2::Guides::WebSocket> for details.

This helper is EXPERIMENTAL.

=cut

sub dispatch_to_swagger {
  return undef unless $_[1]->{op} and $_[1]->{id} and ref $_[1]->{params} eq 'HASH';

  my ($c, $data) = @_;
  my $self     = $c->stash('swagger.plugin');
  my $reply    = sub { $_[0]->send({json => {code => $_[2] || 200, id => $data->{id}, body => $_[1]}}) };
  my $op_info  = $self->{op_info}{$data->{op}} or return $c->$reply(_error('Unknown operationId.'), 400);
  my $sc_class = $op_info->{class} ||= _find_controller($c, $op_info->{controller});
  my ($input, $method_ref, @errors);

  return $c->$reply(_error('Controller could not be loaded.'), 501) unless $sc_class;
  return $c->$reply(_error(qq(Method "$op_info->{method}" not implemented.)), 501)
    unless $method_ref = $sc_class->can($op_info->{method});

  for my $p (@{$op_info->{spec}{parameters} || []}) {
    my $name  = $p->{name};
    my $value = $data->{params}{$name} // $p->{default};
    my @e     = $self->_validate_value($p, $name => $value);
    $input->{$name} = $value unless @e;
    push @errors, @e;
  }

  return $c->$reply({errors => \@errors}, 400) if @errors;
  return Mojo::IOLoop->delay(
    sub {
      my $delay = shift;
      my $sc = $delay->data->{sc} = $sc_class->new(tx => $c->tx);
      $sc->stash(swagger_operation_spec => $op_info->{spec});
      $sc->$method_ref($input, $delay->begin);
    },
    sub {
      my $delay  = shift;
      my $data   = shift;
      my $status = shift || 200;
      my $format = $op_info->{spec}{responses}{$status} || $op_info->{spec}{responses}{default} || undef;
      my @errors
        = !$format ? $self->_validator->validate($data, {})
        : $format->{schema} ? $self->_validator->validate($data, $format->{schema})
        :                     ();

      return $c->$reply($data, $status) unless @errors;
      warn "[Swagger2] Invalid response: @errors\n" if DEBUG;
      $c->$reply({errors => \@errors}, 500);
    },
  );
}

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
  if (!$app->plugins->has_subscribers('swagger_route_added')) {
    $app->hook(swagger_route_added => \&_on_route_added);
  }

  local $config->{coerce} = $config->{coerce} || $ENV{SWAGGER_COERCE_VALUES};
  $self->_validator->coerce($config->{coerce}) if $config->{coerce};
  $self->url($swagger->url);
  $app->helper(dispatch_to_swagger => \&dispatch_to_swagger) unless $app->renderer->get_helper('dispatch_to_swagger');
  $app->helper(render_swagger      => \&render_swagger)      unless $app->renderer->get_helper('render_swagger');

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

  for my $path (sort { length $a <=> length $b } keys %$paths) {
    $paths->{$path}{'x-mojo-around-action'} ||= $swagger->api_spec->get('/x-mojo-around-action');
    $paths->{$path}{'x-mojo-controller'}    ||= $swagger->api_spec->get('/x-mojo-controller');

    for my $http_method (grep { !/^x-/ } keys %{$paths->{$path}}) {
      my $op_spec    = $paths->{$path}{$http_method};
      my $route_path = $path;
      my %parameters = map { ($_->{name}, $_) } @{$op_spec->{parameters} || []};

      $route_path =~ s/{([^}]+)}/{
        my $name = $1;
        my $type = $parameters{$name}{'x-mojo-placeholder'} || ':';
        "($type$name)";
      }/ge;

      $op_spec->{'x-mojo-around-action'} ||= $paths->{$path}{'x-mojo-around-action'};
      $op_spec->{'x-mojo-controller'}    ||= $paths->{$path}{'x-mojo-controller'};
      $app->plugins->emit(
        swagger_route_added => $r->$http_method($route_path => $self->_generate_request_handler($op_spec)));
      warn "[Swagger2] Add route $http_method $route_path\n" if DEBUG;
    }
  }

  # EXPERIMENTAL: Need documentation and probably a better route name()
  if (my $title = $swagger->api_spec->get('/info/title')) {
    my $md5
      = Mojo::Util::md5_sum(
      Data::Dumper->new([$swagger->api_spec->data])->Indent(0)->Pair('=>')->Purity(1)->Quotekeys(1)->Sortkeys(1)
        ->Terse(1)->Useqq(1)->Dump);
    $title =~ s!\W!_!g;
    $r->get("/$md5", [format => [qw( json )]], {format => 'json'})
      ->to(cb => sub { shift->render(json => $swagger->api_spec->data) })->name(lc $title);
  }

  $swagger->api_spec->data->{basePath} = $r->to_string;

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

sub _find_controller_and_method {
  my ($self, $op_spec) = @_;
  my $op = $op_spec->{operationId} or _die($op_spec, "operationId must be present in the swagger spec.");

  if ($op_spec->{'x-mojo-controller'}) {
    return $op_spec->{'x-mojo-controller'}, decamelize ucfirst $op;
  }
  else {
    my ($method, $controller) = $op =~ /^([a-z]+)$SKIP_OP_RE([A-Z][a-z]+)/;    # "showPetById" = ("show", "Pet")
    $controller or _die($op_spec, "Cannot figure out method and controller from operationId '$op'.");
    return $controller, $method;
  }
}

sub _generate_request_handler {
  my ($self,       $op_spec) = @_;
  my ($controller, $method)  = $self->_find_controller_and_method($op_spec);
  my $defaults = {swagger_operation_spec => $op_spec};
  my $op_info = {controller => $controller, method => $method, spec => $op_spec};

  my $handler = sub {
    my $c = shift;
    my ($method_ref, $v, $input);

    unless ($op_info->{class} ||= _find_controller($c, $controller)) {
      return $c->render_swagger(_error('Controller could not be loaded.'), {}, 501);
    }
    unless ($method_ref = $op_info->{class}->can($method)) {
      $method_ref = $op_info->{class}->can(sprintf '%s_%s', $method, lc $c->req->method)
        and warn "HTTP method name is not used in method name lookup anymore!";
    }
    unless ($method_ref) {
      $c->app->log->error(
        qq(Can't locate object method "$method" via package "$op_info->{class}". (Something is wrong in @{[$self->url]})")
      );
      return $c->render_swagger(_error(qq(Method "$method" not implemented.)), {}, 501);
    }

    bless $c, $op_info->{class};    # ugly hack?
    ($v, $input) = $self->_validate_input($c, $op_spec);

    return $c->render_swagger($v, {}, 400) if @{$v->{errors}};
    return $c->delay(
      sub {
        $c->app->log->debug("Swagger2 calling $op_info->{class}\->$method(\$input, \$cb)");
        $c->$method_ref($input, shift->begin);
      },
      sub {
        my $delay  = shift;
        my $data   = shift;
        my $status = shift || 200;
        my $format = $op_spec->{responses}{$status} || $op_spec->{responses}{default} || undef;
        my @errors
          = !$format ? $self->_validator->validate($data, {})
          : $format->{schema} ? $self->_validator->validate($data, $format->{schema})
          :                     ();

        return $c->render_swagger({}, $data, $status) unless @errors;
        warn "[Swagger2] Invalid response: @errors\n" if DEBUG;
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

  $self->{op_info}{$op_spec->{operationId}} = $op_info;
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

sub _validate_input {
  my ($self, $c, $op_spec) = @_;
  my $body    = $c->req->body_params;
  my $headers = $c->req->headers;
  my $query   = $c->req->url->query;
  my (%input, @errors);

  for my $p (@{$op_spec->{parameters} || []}) {
    my ($in, $name, $type) = @$p{qw( in name type )};
    my $value
      = $in eq 'query'    ? $query->param($name)
      : $in eq 'path'     ? $c->stash($name)
      : $in eq 'header'   ? $headers->header($name)
      : $in eq 'body'     ? $c->req->json
      : $in eq 'formData' ? $body->param($name)
      :                     "Invalid 'in' for parameter $name in schema definition";

    if ($type and defined($value //= $p->{default})) {
      if (($type eq 'integer' or $type eq 'number') and $value =~ /^-?\d/) {
        $value += 0;
      }
      elsif ($type eq 'boolean') {
        $value = (!$value or $value eq 'false') ? Mojo::JSON->false : Mojo::JSON->true;
      }
      elsif (ref $p->{items} eq 'HASH' and $p->{items}{collectionFormat}) {
        $value = _coerce_by_collection_format($p->{items}, $value);
      }
    }

    my @e = $self->_validate_value($p, $name => $value);
    $input{$name} = $value unless @e;
    push @errors, @e;
  }

  return {errors => \@errors}, \%input;
}

sub _validate_value {
  my ($self, $p, $name, $value) = @_;
  my $type = $p->{type} || 'object';
  my @e;

  return if !defined $value and !Swagger2::_is_true($p->{required});

  my $schema = {properties => {$name => $p}, required => [$p->{required} ? ($name) : ()]};
  my $in = $p->{in};

  # ugly hack

  if ($in eq 'body') {
    warn "[Swagger2] Validate $in body\n" if DEBUG;
    return
      map { $_->{path} = $_->{path} eq "/" ? "/$name" : "/$name$_->{path}"; $_; }
      $self->_validator->validate($value, $p->{schema});
  }
  elsif (defined $value) {
    warn "[Swagger2] Validate $in $name=$value\n" if DEBUG;
    return $self->_validator->validate({$name => $value}, $schema);
  }
  else {
    warn "[Swagger2] Validate $in $name=undef()\n" if DEBUG;
    return $self->_validator->validate({}, $schema);
  }

  return;
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

sub _error {
  return {errors => [{message => $_[0], path => '/'}]};
}

sub _find_controller {
  my ($c, $moniker) = @_;
  my $controller = $moniker;

  return $controller if $controller =~ /::/ and !defined load_class $controller;
  $controller =~ s!s$!!;    # plural to singular, "::Pets" to "::Pet"

  for my $ns (@{$c->app->routes->namespaces}) {
    my $class = "${ns}::$controller";
    return $class unless defined load_class $class;
  }

  $c->app->log->error(qq(Could not find controller class for "$moniker": $@));
  return;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014-2015, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
