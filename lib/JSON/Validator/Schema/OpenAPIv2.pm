package JSON::Validator::Schema::OpenAPIv2;
use Mojo::Base 'JSON::Validator::Schema::Draft4';

has moniker       => 'openapiv2';
has specification => 'http://swagger.io/v2/schema.json';

sub coerce {
  my $self = shift;
  return $self->SUPER::coerce(@_) if @_;
  $self->{coerce} ||= {booleans => 1, numbers => 1, strings => 1};
  return $self->{coerce};
}

sub new {
  my $self = shift->SUPER::new(@_);
  $self->coerce;    # make sure this attribute is built
  $self;
}

sub parameters_for_request {
  my ($self, $method_path) = @_;
  return [];
}

sub parameters_for_response {
  my ($self, $method_path) = @_;
  return [];
}

sub validate_request {
  my ($self, $method_path, $req) = @_;
  return;
}

sub validate_response {
  my ($self, $method_path, $res) = @_;
  return;
}

sub _build_formats {
  my $self = shift;

  return {
    'binary'    => sub {undef},
    'byte'      => JSON::Validator::Formats->can('check_byte'),
    'date'      => JSON::Validator::Formats->can('check_date'),
    'date-time' => JSON::Validator::Formats->can('check_date_time'),
    'double'    => JSON::Validator::Formats->can('check_double'),
    'email'     => JSON::Validator::Formats->can('check_email'),
    'float'     => JSON::Validator::Formats->can('check_float'),
    'hostname'  => JSON::Validator::Formats->can('check_hostname'),
    'int32'     => JSON::Validator::Formats->can('check_int32'),
    'int64'     => JSON::Validator::Formats->can('check_int64'),
    'ipv4'      => JSON::Validator::Formats->can('check_ipv4'),
    'ipv6'      => JSON::Validator::Formats->can('check_ipv6'),
    'password'  => sub {undef},
    'regex'     => JSON::Validator::Formats->can('check_regex'),
    'uri'       => JSON::Validator::Formats->can('check_uri'),
  };
}

1;

=encoding utf8

=head1 NAME

JSON::Validator::Schema::OpenAPIv2 - OpenAPI version 2 / Swagger

=head1 SYNOPSIS

  use JSON::Validator;
  my $schema = JSON::Validator->new->schema("...")->schema;

  # Check for specification errors
  my $errors = $schema->errors;

  my @request_errors = $schema->validate_request(
    [get => "/path"],
    {body => sub { return {exists => 1, value => {}} }},
  );

  my @response_errors = $schema->validate_response(
    [get => "/path", 200],
    {body => sub { return {exists => 1, value => {}} }},
  );

=head1 DESCRIPTION

This class represents L<http://swagger.io/v2/schema.json>.

=head1 ATTRIBUTES

=head2 moniker

  $str    = $schema->moniker;
  $schema = $schema->moniker("openapiv2");

Used to get/set the moniker for the given schema. Default value is "openapiv2".

=head2 specification

  my $str    = $schema->specification;
  my $schema = $schema->specification($str);

Defaults to "L<http://swagger.io/v2/schema.json>".

=head1 METHODS

=head2 coerce

Coercion is enabled by default, since headers, path parts, query parameters,
... are in most cases strings.

See also L<JSON::Validator/coerce>.

=head2 new

See L<JSON::Validator::Schema/new>.

=head2 parameters_for_request

  my $array_ref = $schema->parameters_for_request([$method, $path]);

=head2 parameters_for_response

  my $array_ref = $schema->parameters_for_response([$method, $path]);

=head2 validate_request

  my @errors = $schema->validate_request([$method, $path], \%req);

=head2 validate_response

  my @errors = $schema->validate_response([$method, $path], \%res);

=head1 SEE ALSO

L<JSON::Validator>, L<Mojolicious::Plugin::OpenAPI>,
L<http://openapi-specification-visual-documentation.apihandyman.io/>

=cut
