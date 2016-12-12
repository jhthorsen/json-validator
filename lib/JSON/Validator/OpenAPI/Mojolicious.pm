package JSON::Validator::OpenAPI::Mojolicious;
use Mojo::Base 'JSON::Validator::OpenAPI';

sub _get_request_data {
  my ($self, $c, $in) = @_;

  return $c->req->url->query->to_hash(1)  if $in eq 'query';
  return $c->match->stack->[-1]           if $in eq 'path';
  return $c->req->body_params->to_hash(1) if $in eq 'formData';
  return $c->req->headers->to_hash(1)     if $in eq 'header';
  return $c->req->json                    if $in eq 'body';
  JSON::Validator::OpenAPI::_confess_invalid_in($in);
}

sub _get_request_uploads {
  my ($self, $c, $name) = @_;
  return $c->req->every_upload($name);
}

sub _get_response_data {
  my ($self, $c, $in) = @_;
  return $c->res->headers->to_hash(1) if $in eq 'header';
  JSON::Validator::OpenAPI::_confess_invalid_in($in);
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
  elsif ($in ne 'body') {    # no need to write body back
    JSON::Validator::OpenAPI::_confess_invalid_in($in);
  }
}

sub _set_response_data {
  my ($self, $c, $in, $name => $value) = @_;
  return $c->res->headers->header($name => ref $value ? @$value : $value) if $in eq 'header';
  JSON::Validator::OpenAPI::_confess_invalid_in($in);
}

1;

=encoding utf8

=head1 NAME

JSON::Validator::OpenAPI::Mojolicious - Request/response adapter for Mojolicious

=head1 SYNOPSIS

See L<JSON::Validator::OpenAPI/SYNOPSIS>.

=head1 DESCRIPTION

This module contains private methods to get/set request/response data for
L<Mojolicious>.

=head1 SEE ALSO

L<Mojolicious::Plugin::OpenAPI>.

L<JSON::Validator>.

=cut
