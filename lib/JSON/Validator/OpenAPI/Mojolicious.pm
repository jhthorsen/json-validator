package JSON::Validator::OpenAPI::Mojolicious;

use Mojo::Base 'JSON::Validator::OpenAPI';

sub _extract_upload {
  my ($self, $c, $name) = @_;

  return $c->req->upload($name);
}

sub _extract_headers {
  my ($self, $c) = @_;

  return $c->res->headers;
}

sub _extract_request_parameter {
  my ($self, $c, $in) = @_;

  return $c->req->url->query->to_hash  if $in eq 'query';
  return $c->match->stack->[-1]        if $in eq 'path';
  return $c->req->body_params->to_hash if $in eq 'formData';
  return $c->req->headers->to_hash     if $in eq 'header';
  return $c->req->json                 if $in eq 'body';
  return {};

}

sub _set_request_parameter {
  my ($self, $c, $p, $value) = @_;
  my ($in, $name) = @$p{qw(in name)};

  if ($in eq 'query') {
    $c->req->url->query([$name => $value]);
    $c->req->params->merge($name => $value);
  }
  elsif ($in eq 'path') {
    $c->stash($name => $value);
  }
  elsif ($in eq 'formData') {
    $c->req->params->merge($name => $value);
    $c->req->body_params->merge($name => $value);
  }
  elsif ($in eq 'header') {
    $c->req->headers->header($name => $value);
  }
  elsif ($in eq 'body') {
    return;    # no need to write body back
  }
  else {
    die
      "Cannot set default for $in => $name. Please submit a ticket here: https://github.com/jhthorsen/mojolicious-plugin-openapi";
  }
}

1;
