package JSON::Validator::Schema::OpenAPIv2;
use Mojo::Base 'JSON::Validator::Schema';

use JSON::Validator::Util qw(E json_pointer);
use Mojo::JSON qw(false true);
use Mojo::URL;
use Scalar::Util 'looks_like_number';
use Time::Local ();

use constant DEBUG => $ENV{JSON_VALIDATOR_DEBUG} || 0;

has allow_invalid_ref => 0;

has default_response_schema => sub {
  return {
    type       => 'object',
    required   => ['errors'],
    properties => {
      errors => {
        type  => 'array',
        items => {
          type     => 'object',
          required => ['message'],
          properties =>
            {message => {type => 'string'}, path => {type => 'string'}}
        },
      },
    },
  };
};

has errors => sub {
  my $self = shift;
  my @errors
    = $self->new(%$self, allow_invalid_ref => 0)->data($self->specification)
    ->validate($self->data);
  return \@errors;
};

has specification => 'http://swagger.io/v2/schema.json';

sub base_url {
  my $self = shift;
  my $data = $self->data;

  # Set
  if (@_) {
    my $url = Mojo::URL->new(shift);
    $data->{schemes}[0] = $url->scheme    if $url->scheme;
    $data->{host}       = $url->host_port if $url->host_port;
    $data->{basePath}   = $url->path      if $url->path;
    return $self;
  }

  # Get
  my $url = Mojo::URL->new;
  if ($data->{host}) {
    my $schemes = $data->{schemes} || [];
    my ($host, $port) = split ':', $data->{host};
    $url->scheme($schemes->[0] || 'http');
    $url->host($host) if length $host;
    $url->port($port) if length $port;
  }

  return $url->path($data->{basePath} || '/');
}

sub data {
  my $self = shift;
  return $self->{data} ||= {} unless @_;

  if ($self->allow_invalid_ref) {
    my $clone = $self->new(%$self, allow_invalid_ref => 0);
    $self->{data} = $clone->data(shift)->bundle({replace => 1})->data;
  }
  else {
    $self->{data} = $self->_resolve(shift);
  }

  if (my $class = $self->version_from_class) {
    my $version = $class->can('VERSION') && $class->VERSION;
    $self->{data}{info}{version} = "$version" if length $version;
  }

  delete $self->{errors};
  return $self;
}

sub ensure_default_response {
  my ($self, $params) = @_;

  my $name       = $params->{name} || 'DefaultResponse';
  my $def_schema = $self->_sub_schemas->{$name}
    ||= $self->default_response_schema;
  tie my %ref, 'JSON::Validator::Ref', $def_schema,
    json_pointer $self->_sub_schemas_pointer, $name;

  my $codes      = $params->{codes} || [400, 401, 404, 500, 501];
  my $res_schema = $self->_response_schema(\%ref);
  $self->get(
    ['paths', undef, undef, 'responses'],
    sub { $_[0]->{$_} ||= $res_schema for @$codes },
  );

  delete $self->{errors};
  return $self;
}

sub validate_request {
  my ($self, $c, $method_path) = @_;
  my $parameters = $self->_build_req_parameters(@$method_path);
  my @errors;

  for my $param (@$parameters) {
    my $val = $c->openapi->get_req_value($param);
    $val->{exists} = ($val->{exists} // defined $val->{value}) ? true : false;
    $val->{name} ||= $param->{name};
    $self->_set_default_value_from_schema($val, $param) unless $val->{exists};

    if ($val->{exists}) {
      local $self->{validate_request} = 1;
      my $schema
        = $val->{content_type} && $param->{consumes}{$val->{content_type}};
      $schema //= $param->{'x-json-schema'} || $param->{schema} || $param;
      my @e = map { $_->path(_prefix_path($param->{name}, $_->path)); $_ }
        $self->validate($val->{value}, $schema);
      $c->openapi->set_req_value($val) unless @e;
      push @errors, @e;
    }
    elsif ($param->{required}) {
      push @errors, E "/$param->{name}", [qw(object required)];
    }
  }

  return @errors;
}

sub validate_response {
  my ($self, $c, $method_path_status) = @_;
  my $parameters = $self->_build_res_parameters(@$method_path_status);
  return E '/', 'No response rules defined.' unless $parameters;

  my @errors;
  for my $param (@$parameters) {
    my $val = $c->openapi->get_res_value($param);
    $self->_set_default_value_from_schema($val, $param)
      unless $val->{exists} //= defined $val->{value};

    if ($val->{exists}) {
      my $schema
        = $val->{content_type} && $param->{produces}{$val->{content_type}};
      $schema //= $param->{'x-json-schema'} || $param->{schema} || $param;
      push @errors,
        map { $_->path(_prefix_path($param->{name}, $_->path)); $_ }
        $self->validate($val->{value}, $schema);
    }
    elsif ($param->{required}) {
      push @errors, E "/$param->{name}", [qw(object required)];
    }
  }

  return @errors;
}

sub version_from_class {
  my $self = shift;
  return $self->{version_from_class} || '' unless @_;

  my $class = shift;
  $self->{version_from_class} = $class;
  $self->{data}{info}{version} = $class->VERSION;
  return $self;
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

sub _build_req_parameters {
  my ($self, $method, $path) = @_;

  my $cache_key = "$method:$path";
  return $self->{request_parameters}{$cache_key}
    if $self->{request_parameters}{$cache_key};

  my @parameters
    = map {@$_} $self->_find_all_nodes([paths => $path, $method], 'parameters');

  my @consumes
    = map {@$_} $self->_find_all_nodes([paths => $path, $method], 'consumes');
  @consumes = ('application/json') unless @consumes;
  for my $param (@parameters) {
    $param->{consumes} = {map { ($_ => $param->{schema}) } @consumes}
      if $param->{in} eq 'body';
    $param->{style} = _translate_collection_format($param)
      if $param->{collectionFormat};
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

  my $produces
    = [$self->_find_all_nodes([paths => $path, $method], 'produces')];
  $produces = pop(@$produces) || ['application/json'];
  if (exists $response->{schema}) {
    push @parameters,
      {
      in       => 'body',
      name     => 'body',
      produces => {map { ($_ => $response->{schema}) } @$produces},
      };
  }

  return $self->{response_parameters}{$cache_key} = \@parameters;
}

sub _find_all_nodes {
  my ($self, $pointer, $leaf) = @_;
  my @found;
  push @found, $self->data->{$leaf} if exists $self->data->{$leaf};

  my @path;
  for my $p (@$pointer) {
    push @path, $p;
    my $node = $self->get([@path]);
    push @found, $node->{$leaf} if exists $node->{$leaf};
  }

  return @found;
}

sub _prefix_path {
  return join '', "/$_[0]", $_[1] =~ /\w/ ? ($_[1]) : ();
}

sub _resolve_ref {
  my ($self, $topic, $url) = @_;

# https://github.com/OAI/OpenAPI-Specification/blob/3a29219e07b01be93bcbede32e861e6c5b8e77c3/examples/wordnik/petstore.yaml#L37
  $topic->{'$ref'} = "#/definitions/$topic->{'$ref'}"
    if $topic->{'$ref'} =~ /^\w+$/;

  return $self->SUPER::_resolve_ref($topic, $url);
}

sub _response_schema {
  my ($self, $schema) = @_;
  return {description => 'Default response.', schema => $schema};
}

sub _set_default_value_from_schema {
  my ($self, $val, $param) = @_;

  if ($param->{schema} and exists $param->{schema}{default}) {
    @$val{qw(exists value)} = (1, $param->{schema}{default});
  }
  elsif (exists $param->{default}) {
    @$val{qw(exists value)} = (1, $param->{default});
  }
}

sub _sub_schemas         { shift->data->{definitions} ||= {} }
sub _sub_schemas_pointer {'#/definitions'}

sub _translate_collection_format {
  my $p = shift;

  return
      $p->{collectionFormat} eq 'pipes'          ? 'pipeDelimited'
    : $p->{collectionFormat} eq 'ssv'            ? 'spaceDelimited'
    : $p->{collectionFormat} eq 'tsv'            ? 'tabsDelimited'
    : (grep { $_ eq $p->{in} } qw(cookie query)) ? 'form'
    :                                              'simple';
}

sub _validate_type_file {
  my ($self, $data, $path, $schema) = @_;

  return unless $schema->{required} and (not defined $data or not length $data);
  return E $path => 'Missing property.';
}

sub _validate_type_object {
  my ($self, $data, $path, $schema) = @_;
  return shift->SUPER::_validate_type_object(@_) unless ref $data eq 'HASH';
  return shift->SUPER::_validate_type_object(@_)
    unless $self->{validate_request};

  my (@errors, %ro);
  for my $name (keys %{$schema->{properties} || {}}) {
    next unless $schema->{properties}{$name}{readOnly};
    push @errors, E "$path/$name", "Read-only." if exists $data->{$name};
    $ro{$name} = 1;
  }

  my $discriminator = $schema->{discriminator};
  if ($discriminator and !$self->{inside_discriminator}) {
    return E $path, "Discriminator $discriminator has no value."
      unless my $name = $data->{$discriminator};
    return E $path, "No definition for discriminator $name."
      unless my $dschema = $self->get("/definitions/$name");
    local $self->{inside_discriminator} = 1;    # prevent recursion
    return $self->_validate($data, $path, $dschema);
  }

  local $schema->{required} = [grep { !$ro{$_} } @{$schema->{required} || []}];

  return @errors, $self->SUPER::_validate_type_object($data, $path, $schema);
}

1;

=encoding utf8

=head1 NAME

JSON::Validator::Schema::OpenAPIv2 - OpenAPI version 2 / Swagger

=head1 SYNOPSIS

  use JSON::Validator::Schema::OpenAPIv2;
  my $schema = JSON::Validator::Schema::OpenAPIv2->new({...});

  # Validate request against a sub schema
  my $sub_schema = $schema->get("/paths/whatever/get");
  my @errors = $schema->validate_request($c, $sub_schema);
  if (@errors) return $c->render(json => {errors => \@errors}, status => 400);

  # Do your logic inside the controller
  my $res = $c->model->get_stuff;

  # Validate response against a sub schema
  @errors = $schema->validate_response($c, $sub_schema, 200, $res);
  if (@errors) return $c->render(json => {errors => \@errors}, status => 500);

  return $c->render(json => $res);

See L<Mojolicious::Plugin::OpenAPI> for a simpler way of using
L<JSON::Validator::Schema::OpenAPIv2>.

=head1 DESCRIPTION

This class represents L<http://swagger.io/v2/schema.json>.

=head1 ATTRIBUTES

=head2 allow_invalid_ref

  $bool   = $schema->allow_invalid_ref;
  $schema = $schema->allow_invalid_ref(1);

Setting this attribute to a true value, will resolve all the "$ref"s inside the
schema before it is set in L</data>. This can be useful if you don't want to be
restricted by the shortcomings of the OpenAPIv2 specification, but still want a
valid schema.

Note however that circular "$ref"s I<are> not supported by this.

=head2 default_response_schema

  $schema   = $schema->default_response_schema($hash_ref);
  $hash_ref = $schema->default_response_schema;

Holds the structure of the default response schema added by
L</ensure_default_response>.

=head2 errors

  $array_ref = $schema->errors;

Uses L</specification> to validate L</data> and returns an array-ref of
L<JSON::Validator::Error> objects if L</data> contains an invalid schema.

=head2 formats

  $schema   = $schema->formats({});
  $hash_ref = $schema->formats;

Open API support the following formats in addition to the formats defined in
L<JSON::Validator::Schema::Draft4>:

=over 4

=item * byte

A padded, base64-encoded string of bytes, encoded with a URL and filename safe
alphabet. Defined by RFC4648.

=item * date

An RFC3339 date in the format YYYY-MM-DD

=item * double

Cannot test double values with higher precision then what
the "number" type already provides.

=item * float

Will always be true if the input is a number, meaning there is no difference
between  L</float> and L</double>. Patches are welcome.

=item * int32

A signed 32 bit integer.

=item * int64

A signed 64 bit integer. Note: This check is only available if Perl is
compiled to use 64 bit integers.

=back

=head2 specification

  my $str    = $schema->specification;
  my $schema = $schema->specification($str);

Defaults to "L<http://swagger.io/v2/schema.json>".

=head1 METHODS

=head2 base_url

  $schema = $schema->base_url("https://example.com/api");
  $schema = $schema->base_url(Mojo::URL->new("https://example.com/api"));
  $url    = $schema->base_url;

Can either retrieve or set the base URL for this schema. This method will
construct the C<$url> from "/schemes/0", "/host" and "/basePath" in the schema
or set all or some of those attributes from the input URL.

=head2 data

Same as L<JSON::Validator::Schema/data>, but will bundle the schema if
L</allow_invalid_ref> is set, and also change "/data/info/version" if
L</version_from_class> is set.

=head2 ensure_default_response

  $schema = $schema->ensure_default_response({codes => [400, 500], name => "DefaultResponse"});
  $schema = $schema->ensure_default_response;

This method will look through the "responses" definitions in the schema and add
response definitions, unless already defined. The default schema will allow
responses like this:

  {"errors":[{"message:"..."}]}
  {"errors":[{"message:"...","path":"/foo"}]}

=head2 validate_request

  my @errors = $schema->validate_request($c, [$http_method, $api_path]);

Used to validate a web request using rules found in L</data> using C<$api_path>
and C<$http_method>. The C<$c> (controller object) need to support this API:

  my $input = $c->openapi->get_req_value($param);
  $c->openapi->set_req_value($input);

=head2 validate_response

  my @errors = $schema->validate_request($c, [$http_method, $api_path, $status]);

Used to validate a web request using rules found in L</data> using
C<$api_path>, C<$http_method> and C<$status>. The C<$c> (controller object)
need to support this API:

  my $output = $c->openapi->get_res_value($param);

=head2 version_from_class

  my $str    = $schema->version_from_class;
  my $schema = $schema->version_from_class("My::App");

The class name (if present) will be used to set "/data/info/version" inside the
schame stored in L</data>.

=head1 SEE ALSO

L<JSON::Validator>, L<Mojolicious::Plugin::OpenAPI>,
L<http://openapi-specification-visual-documentation.apihandyman.io/>

=cut
