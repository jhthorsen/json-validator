package t::OpenApiApp;
use Mojo::Base 'Mojolicious';

has schema => undef;

sub startup {
  my $app = shift;

  # Required helpers
  $app->helper('openapi.get_req_value' => \&_openapi_get_req_value);
  $app->helper('openapi.get_res_value' => \&_openapi_get_res_value);
  $app->helper(
    'openapi.set_req_value' => sub {
      my ($c, $input) = @_;
      push @{$c->stash->{input}}, $input;
    }
  );

  # Dummy test routes
  $app->routes->any('/:schemaPath' => \&_action);
  $app->routes->any(
    '/pets/:petId' => {schemaPath => 'pets/{petId}'},
    \&_action
  );
}

sub _action {
  my $c          = shift;
  my $path       = sprintf '/%s', $c->stash('schemaPath');
  my $method     = lc $c->req->method;
  my @req_errors = $c->app->schema->validate_request($c, [$method, $path]);

  my $res = {};
  $c->app->plugins->emit_hook(make_response => $c, $res);
  $c->res->headers->header($_ => $res->{headers}{$_})
    for keys %{$res->{headers} || {}};
  $c->stash(openapi => $res->{openapi}) if exists $res->{openapi};

  my $status = $c->param('status');
  my @res_errors
    = $c->app->schema->validate_response($c, [$method, $path, $status]);

  $c->render(
    status => $status,
    json   => {
      req        => $c->stash('input'),
      req_errors => \@req_errors,
      res        => $c->stash('openapi'),
      res_errors => \@res_errors,
    },
  );
}

sub _openapi_get_req_value {
  my ($c, $p) = @_;
  my $req = $c->req;

  return {value => $req->url->query->param($p->{name})} if $p->{in} eq 'query';
  return {value => $c->match->stack->[-1]{$p->{name}}}  if $p->{in} eq 'path';
  return {value => $req->body_params->param($p->{name})
      || $req->upload($p->{name})}
    if $p->{in} eq 'formData';
  return {value => $req->cookie($p->{name})}          if $p->{in} eq 'cookie';
  return {value => $req->headers->header($p->{name})} if $p->{in} eq 'header';

  if ($p->{in} eq 'body') {
    return {
      content_type => 'application/json',
      exists       => $req->body_size,
      value => $p->{consumes}{'application/json'} ? $c->req->json : undef,
    };
  }

  die "[openapi.get_req_value] Unsupported in: $p->{in}";
}

sub _openapi_get_res_value {
  my ($c, $p) = @_;

  if ($p->{in} eq 'header') {
    return {value => $c->res->headers->header($p->{name})};
  }

  if ($p->{in} eq 'body') {
    return {
      content_type => 'application/json',
      exists       => exists $c->stash->{openapi},
      value        => $c->stash('openapi'),
    };
  }

  die "[openapi.get_res_value] Unsupported in: $p->{in}";
}

1;
