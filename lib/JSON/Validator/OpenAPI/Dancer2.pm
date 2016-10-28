package JSON::Validator::OpenAPI::Dancer2;

use Hash::MultiValue;
use Mojo::Base 'JSON::Validator::OpenAPI';

### request ###

sub _get_request_data {
  my ($self, $app, $in) = @_;

  return $app->dsl->query_parameters->as_hashref_mixed if $in eq 'query';
  return $app->dsl->route_parameters->as_hashref_mixed if $in eq 'path';
  return $app->dsl->body_parameters->as_hashref_mixed  if $in eq 'formData';
  return Hash::MultiValue->new($app->dsl->request->headers->flatten)->as_hashref_mixed
    if $in eq 'header';
  return $app->dsl->request->data if $in eq 'body';
  return {};    # TODO correct?
}

sub _get_request_uploads {
  my ($self, $app, $name) = @_;

  return ($app->request->upload($name));    # context-aware
}

sub _set_request_data {
  my ($self, $app, $in, $name => $value) = @_;

  if ($in eq 'query') {
    $app->dsl->query_parameters->set($name => $value);
    $app->dsl->request->params->{$name} = $value;
  }
  elsif ($in eq 'path') {
    $app->dsl->route_parameters->set($name => $value);
  }
  elsif ($in eq 'formData') {
    $app->dsl->request->body_parameters->set($name => $value);
    $app->dsl->request->params->{$name} = $value;
  }
  elsif ($in eq 'header') {
    $app->dsl->request->headers->header($name => $value);
  }
  elsif ($in eq 'body') { }    # no need to write body back
  else {
    die
      "Cannot set default for $in => $name. Please submit a ticket here: https://github.com/jhthorsen/mojolicious-plugin-openapi";
  }
}

### response

sub _get_response_data {
  my ($self, $app, $in) = @_;

  if ($in eq 'header') {
    my @headers = $app->response->headers->flatten;
    return Hash::MultiValue->new(@headers)->as_hashref_mixed;
  }

  # TODO what else?
}

sub _set_response_data {
  my ($self, $app, $in, $name => $value) = @_;

  $in eq 'header' and $app->response->headers->header($name => $value);

  # TODO what else?
}

1;
