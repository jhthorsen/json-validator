package JSON::Validator::OpenAPI::Dancer2;

use Carp qw(confess);
use Hash::MultiValue;
use Mojo::Base 'JSON::Validator::OpenAPI';

### request ###

sub _get_request_data {
  my ($self, $dsl, $in) = @_;

  if ($in eq 'query') {
    return $dsl->query_parameters->as_hashref_mixed;
  }
  elsif ($in eq 'path') {
    return $dsl->route_parameters->as_hashref_mixed;
  }
  elsif ($in eq 'formData') {
    return $dsl->body_parameters->as_hashref_mixed;
  }
  elsif ($in eq 'header') {
    return Hash::MultiValue->new($dsl->app->request->headers->flatten)->as_hashref_mixed;
  }
  elsif ($in eq 'body') {
    return $dsl->app->request->data;
  }
  else {
    $self->_invalid_in($in);
  }
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
    $self->_invalid_in($in);
  }
}

### response

sub _get_response_data {
  my ($self, $dsl, $in) = @_;

  if ($in eq 'header') {
    my @headers = $dsl->response->headers->flatten;
    return Hash::MultiValue->new(@headers)->as_hashref_mixed;
  }
  else {
    $self->_invalid_in($in);
  }
}

sub _set_response_data {
  my ($self, $dsl, $in, $name => $value) = @_;

  if ($in eq 'header') {
    $dsl->response->headers->header($name => $value);
  }
  else {
    $self->_invalid_in($in);
  }
}

1;
