package JSON::Validator::OpenAPI::Mojolicious;

use Carp qw(confess);
use Mojo::Base 'JSON::Validator::OpenAPI';

### request ###

sub _get_request_data {
  my ($self, $c, $in) = @_;

  return $c->req->url->query->to_hash(1)  if $in eq 'query';
  return $c->match->stack->[-1]           if $in eq 'path';
  return $c->req->body_params->to_hash(1) if $in eq 'formData';
  return $c->req->headers->to_hash(1)     if $in eq 'header';
  return $c->req->json                    if $in eq 'body';
  $self->_invalid_in($in);
}

sub _get_request_uploads {
  my ($self, $c, $name) = @_;

  return @{$c->req->every_upload($name)};
}

sub _set_request_data {
  my ($self, $c, $in, $name => $value) = @_;

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
  elsif ($in eq 'body') { }    # no need to write body back
  else {
    $self->_invalid_in($in);
  }
}

### response

sub _get_response_data {
  my ($self, $c, $in) = @_;

  if ($in eq 'header') {
    return $c->res->headers->to_hash(1);
  }
  else {
    $self->_invalid_in($in);
  }
}

sub _set_response_data {
  my ($self, $c, $in, $name => $value) = @_;

  if ($in eq 'header') {
    $c->res->headers->header($name => ref $value ? @$value : $value);
  }
  else {
    $self->_invalid_in($in);
  }
}

1;
