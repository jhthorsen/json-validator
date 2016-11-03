package JSON::Validator::OpenAPI::Dancer2;

use Carp qw(confess);
use Hash::MultiValue;
use Mojo::Base 'JSON::Validator::OpenAPI';

### request ###

sub _get_request_data {
  my ($self, $dsl, $in) = @_;

  return $dsl->query_parameters->as_hashref_mixed if $in eq 'query';
  return $dsl->route_parameters->as_hashref_mixed if $in eq 'path';
  return $dsl->body_parameters->as_hashref_mixed  if $in eq 'formData';
  return Hash::MultiValue->new($dsl->app->request->headers->flatten)->as_hashref_mixed
    if $in eq 'header';
  return $dsl->app->request->data if $in eq 'body';
  confess "Unsupported \$in: $in. Please report at https://github.com/jhthorsen/json-validator";
}

sub _get_request_uploads {
  my ($self, $dsl, $name) = @_;

  return ($dsl->app->request->upload($name));    # context-aware
}

sub _set_request_data {
  my ($self, $dsl, $in, $name => $value) = @_;

  if ($in eq 'query') {
    $dsl->query_parameters->set($name => $value);
    $dsl->app->request->params->{$name} = $value;
  }
  elsif ($in eq 'path') {
    $dsl->route_parameters->set($name => $value);
  }
  elsif ($in eq 'formData') {
    $dsl->app->request->body_parameters->set($name => $value);
    $dsl->app->request->params->{$name} = $value;
  }
  elsif ($in eq 'header') {
    $dsl->app->request->headers->header($name => $value);
  }
  elsif ($in eq 'body') { }    # no need to write body back
  else {
    die
      "Cannot set default for $in => $name. Please submit a ticket here: https://github.com/jhthorsen/mojolicious-plugin-openapi";
  }
}

### response

sub _get_response_data {
  my ($self, $dsl, $in) = @_;

  if ($in eq 'header') {
    my @headers = $dsl->response->headers->flatten;
    return Hash::MultiValue->new(@headers)->as_hashref_mixed;
  }

  # TODO what else?
}

sub _set_response_data {
  my ($self, $dsl, $in, $name => $value) = @_;

  $in eq 'header' and $dsl->response->headers->header($name => $value);

  # TODO what else?
}

1;
