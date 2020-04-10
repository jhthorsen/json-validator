package JSON::Validator::Schema::OpenAPIv3;
use Mojo::Base 'JSON::Validator::Schema::OpenAPIv2';

use JSON::Validator::Formats;
use JSON::Validator::Util 'E';
use Mojo::JSON;
use Mojo::Path;

has errors => sub {
  my $self = shift;
  my $clone
    = $self->new(%$self, allow_invalid_ref => 0)->data($self->specification);
  my @errors = $clone->validate($self->data);
  return \@errors;
};

has specification => 'https://spec.openapis.org/oas/3.0/schema/2019-04-02';

sub base_url {
  my $self = shift;
  my $data = $self->data;

  # Set
  if (@_) {
    my $url    = Mojo::URL->new(shift);
    my $server = Mojo::URL->new($data->{servers}[0]{url} || '/');
    $server->scheme($url->scheme) if $url->scheme;
    $server->host($url->host)     if $url->host;
    $server->port($url->port)     if $url->port;
    $server->path($url->path)     if $url->path;
    $data->{servers}[0]{url} = $server->to_string;
    return $self;
  }

  # Get
  my $servers = $data->{servers} || [];
  return Mojo::URL->new($servers->[0] ? $servers->[0]{url} : '/');
}

sub _build_formats {
  my $self = shift;

  # TODO: Figure out if this is the correct list
  return {
    'binary'        => sub {undef},
    'byte'          => JSON::Validator::Formats->can('check_byte'),
    'date'          => JSON::Validator::Formats->can('check_date'),
    'date-time'     => JSON::Validator::Formats->can('check_date_time'),
    'double'        => JSON::Validator::Formats->can('check_double'),
    'duration'      => JSON::Validator::Formats->can('check_duration'),
    'email'         => JSON::Validator::Formats->can('check_email'),
    'float'         => JSON::Validator::Formats->can('check_float'),
    'hostname'      => JSON::Validator::Formats->can('check_hostname'),
    'idn-email'     => JSON::Validator::Formats->can('check_idn_email'),
    'idn-hostname'  => JSON::Validator::Formats->can('check_idn_hostname'),
    'int32'         => JSON::Validator::Formats->can('check_int32'),
    'int64'         => JSON::Validator::Formats->can('check_int64'),
    'ipv4'          => JSON::Validator::Formats->can('check_ipv4'),
    'ipv6'          => JSON::Validator::Formats->can('check_ipv6'),
    'iri'           => JSON::Validator::Formats->can('check_iri'),
    'iri-reference' => JSON::Validator::Formats->can('check_iri_reference'),
    'json-pointer'  => JSON::Validator::Formats->can('check_json_pointer'),
    'password'      => sub {undef},
    'regex'         => JSON::Validator::Formats->can('check_regex'),
    'relative-json-pointer' =>
      JSON::Validator::Formats->can('check_relative_json_pointer'),
    'time'          => JSON::Validator::Formats->can('check_time'),
    'uri'           => JSON::Validator::Formats->can('check_uri'),
    'uri-reference' => JSON::Validator::Formats->can('check_uri_reference'),
    'uri-template'  => JSON::Validator::Formats->can('check_uri_template'),
    'uuid'          => JSON::Validator::Formats->can('check_uuid'),
  };
}

sub _build_req_parameters {
  my ($self, $method, $path) = @_;

  my $cache_key = "$method:$path";
  return $self->{request_parameters}{$cache_key}
    if $self->{request_parameters}{$cache_key};

  my @parameters
    = map {@$_} $self->_find_all_nodes([paths => $path, $method], 'parameters');

  my $body = $self->get([paths => $path, $method, 'requestBody']);
  if ($body) {
    my $param = {in => 'body', name => 'body', required => $body->{required}};
    $param->{consumes}
      = {map { ($_ => $body->{content}{$_}{schema}) } keys %{$body->{content}}};
    push @parameters, $param;
  }

  return $self->{request_parameters}{$cache_key} = \@parameters;
}

sub _build_res_parameters {
  my ($self, $method, $path, $status) = @_;

  $status ||= 200;
  my $cache_key = "$method:$path:$status";
  return $self->{response_parameters}{$cache_key}
    if $self->{response_parameters}{$cache_key};

  my $responses = $self->get([paths => $path, $method, 'responses']);
  my $response  = $responses->{$status} || $responses->{default};
  return undef unless $response;

  my @parameters;
  if (my $headers = $response->{headers}) {
    push @parameters,
      map { +{schema => $headers->{$_}, in => 'header', name => $_} }
      sort keys %$headers;
  }

  if (my $content = $response->{content}) {
    push @parameters,
      {
      in       => 'body',
      name     => 'body',
      produces => {map { $_ => $content->{$_}{schema} } keys %$content},
      };
  }

  return $self->{response_parameters}{$cache_key} = \@parameters;
}

sub _definitions_path_for_ref {
  my ($self, $ref) = @_;

  # Try to determine the path from the fqn
  # We are only interested in the path in the fqn, so following fqn:
  # "#/components/schemas/some_schema" => ['components', 'schemas']
  my $path
    = Mojo::Path->new($ref->fqn =~ m!^.*#/(components/.+)$!)->to_dir->parts;
  return $path->[0] ? $path : ['components'];
}

sub _response_schema {
  my ($self, $schema) = @_;
  return {
    description => 'Default response.',
    content     => {'application/json' => {schema => $schema}},
  };
}

sub _sub_schemas         { shift->data->{components}{schemas} ||= {} }
sub _sub_schemas_pointer {'#/components/schemas'}

sub _validate_type_object {
  my ($self, $data, $path, $schema) = @_;
  return shift->SUPER::_validate_type_object(@_) unless ref $data eq 'HASH';

  # "nullable" is the same as "type":["null", ...], which is supported by many
  # tools, even though not officially supported by OpenAPI.
  my %properties = %{$schema->{properties} || {}};
  local $schema->{properties} = \%properties;
  for my $key (keys %properties) {
    next unless $properties{$key}{nullable};
    $properties{$key} = {%{$properties{$key}}};
    $properties{$key}{type} = ['null', _to_list($properties{$key}{type})];
  }

  return $self->SUPER::_validate_type_object($_[1], $path, $schema);
}

1;

=encoding utf8

=head1 NAME

JSON::Validator::Schema::OpenAPIv3 - OpenAPI version 3

=head1 SYNOPSIS

See L<JSON::Validator::Schema::OpenAPIv2/SYNOPSIS>.

=head1 DESCRIPTION

This class represents L<https://spec.openapis.org/oas/3.0/schema/2019-04-02>.

=head1 ATTRIBUTES

=head2 specification

  my $str    = $schema->specification;
  my $schema = $schema->specification($str);

Defaults to "L<https://spec.openapis.org/oas/3.0/schema/2019-04-02>".

This URL will be updated once a newer URL is available.

=head1 METHODS

=head2 base_url

  $schema = $schema->base_url("https://example.com/api");
  $schema = $schema->base_url(Mojo::URL->new("https://example.com/api"));
  $url    = $schema->base_url;

Can either retrieve or set the base URL for this schema. This method will
construct the C<$url> from "/servers/0" in the schema, or set it from the input
URL.

=head1 SEE ALSO

L<JSON::Validator>, L<JSON::Validator::Schema::OpenAPIv2>,
L<Mojolicious::Plugin::OpenAPI>.

=cut
