package JSON::Validator::Schema::OpenAPIv2;
use Mojo::Base 'JSON::Validator::Schema::Draft4';

use JSON::Validator::Util qw(E schema_type);

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
  my $self = shift;
  my ($method, $path) = (lc $_[0][0], $_[0][1]);

  my $cache_key = "parameters_for_request:$method:$path";
  return $self->{cache}{$cache_key} if $self->{cache}{$cache_key};
  return undef unless $self->get([paths => $path, $method]);

  my @accepts    = map {@$_} $self->_find_all_nodes([paths => $path, $method], 'consumes');
  my @parameters = map {@$_} $self->_find_all_nodes([paths => $path, $method], 'parameters');
  for my $param (@parameters) {
    $param->{type} ||= schema_type($param->{schema} || $param);
    $param->{accepts} = \@accepts if $param->{in} eq 'body';
  }

  return $self->{cache}{$cache_key} = \@parameters;
}

sub parameters_for_response {
  my $self = shift;
  my ($method, $path, $status) = (lc $_[0][0], $_[0][1], $_[0][2] || 200);

  $status ||= 200;
  my $cache_key = "parameters_for_response:$method:$path:$status";
  return $self->{cache}{$cache_key} if $self->{cache}{$cache_key};

  my $responses = $self->get([paths => $path, $method, 'responses']);
  my $response  = $responses->{$status} || $responses->{default};
  return undef unless $response;

  my @parameters;
  if (my $headers = $response->{headers}) {
    push @parameters, map { +{%{$headers->{$_}}, in => 'header', name => $_} } sort keys %$headers;
  }

  my @accepts = $self->_find_all_nodes([paths => $path, $method], 'produces');
  if (exists $response->{schema}) {
    push @parameters, {%$response, in => 'body', name => 'body', accepts => pop @accepts || []};
  }

  return $self->{cache}{$cache_key} = \@parameters;
}

sub validate_request {
  my ($self, $method_path, $req) = @_;
  my $parameters = $self->parameters_for_request($method_path);

  my %get;
  for my $in (qw(body formData header path query)) {
    $get{$in} = ref $req->{$in} eq 'CODE' ? $req->{$in} : sub {
      my ($name, $params) = @_;
      return {exists => exists $req->{$in}{$name}, value => $req->{$in}{$name}};
    };
  }

  return $self->_validate_request_or_response(request => $parameters, \%get);
}

sub validate_response {
  my ($self, $method_path_status, $res) = @_;
  my $parameters = $self->parameters_for_response($method_path_status);

  my %get;
  for my $in (qw(body header)) {
    $get{$in} = ref $res->{$in} eq 'CODE' ? $res->{$in} : sub {
      my ($name, $params) = @_;
      return {exists => exists $res->{$in}{$name}, value => $res->{$in}{$name}};
    };
  }

  return $self->_validate_request_or_response(response => $parameters, \%get);
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

sub _find_all_nodes {
  my ($self, $pointer, $leaf) = @_;
  my @found;
  push @found, $self->data->{$leaf} if ref $self->data->{$leaf} eq 'ARRAY';

  my @path;
  for my $p (@$pointer) {
    push @path, $p;
    my $node = $self->get([@path]);
    push @found, $node->{$leaf} if ref $node->{$leaf} eq 'ARRAY';
  }

  return @found;
}

sub _prefix_error_path {
  return join '', "/$_[0]", $_[1] =~ /\w/ ? ($_[1]) : ();
}

sub _coerce_by_collection_format {
  my ($self, $val, $format) = @_;
  return $val->{value} = ref $val->{value} eq 'ARRAY' ? $val->{value} : [$val->{value}] if $format eq 'multi';
  return $val->{value} = [split /\|/,  $val->{value}] if $format eq 'pipes';
  return $val->{value} = [split /[ ]/, $val->{value}] if $format eq 'ssv';
  return $val->{value} = [split /\t/,  $val->{value}] if $format eq 'tsv';
  return $val->{value} = [split /,/,   $val->{value}];
}

sub _coerce_default_value {
  my ($self, $val, $param) = @_;

  if ($param->{schema} and exists $param->{schema}{default}) {
    @$val{qw(exists value)} = (1, $param->{schema}{default});
  }
  elsif (exists $param->{default}) {
    @$val{qw(exists value)} = (1, $param->{default});
  }
}

sub _validate_request_or_response {
  my ($self, $direction, $parameters, $get) = @_;

  my @errors;
  for my $param (@$parameters) {
    my $val = $get->{$param->{in}}->($param->{name}, $param);
    @$val{qw(in name valid)} = (@$param{qw(in name)}, 0);
    $self->_coerce_default_value($val, $param) unless $val->{exists};

    if ($param->{in} eq 'body') {
      $val->{content_type} = $param->{accepts}[0] if !$val->{content_type} and @{$param->{accepts}};

      if (@{$param->{accepts}} and !grep { $_ eq $val->{content_type} } @{$param->{accepts}}) {
        my $expected = join ', ', @{$param->{accepts}};
        push @errors, E "/$param->{name}", [$expected => type => $val->{content_type}];
        next;
      }
      if ($param->{required} and !$val->{exists}) {
        push @errors, E "/$param->{name}", [qw(object required)];
        next;
      }
      if ($val->{exists}) {
        local $self->{"validate_$direction"} = 1;
        my @e = map { $_->path(_prefix_error_path($param->{name}, $_->path)); $_ }
          $self->validate($val->{value}, $param->{schema});
        $val->{valid} = 1 unless @e;
        push @errors, @e;
      }
    }
    elsif ($val->{exists}) {
      $self->_coerce_by_collection_format($val, $param->{collectionFormat})
        if $direction eq 'request' and $param->{collectionFormat};
      local $self->{"validate_$direction"} = 1;
      my @e = map { $_->path(_prefix_error_path($param->{name}, $_->path)); $_ } $self->validate($val->{value}, $param);
      $val->{valid} = 1 unless @e;
      push @errors, @e;
    }
    elsif ($param->{required}) {
      push @errors, E "/$param->{name}", [qw(object required)];
    }
  }

  return @errors;
}

sub _validate_type_object {
  my ($self, $data, $path, $schema) = @_;
  return E $path, [object => type => data_type $data] if ref $data ne 'HASH';

  my $discriminator = $schema->{discriminator};
  if ($discriminator and !$self->{inside_discriminator}) {
    return E $path, "Discriminator $discriminator has no value." unless my $name    = $data->{$discriminator};
    return E $path, "No definition for discriminator $name."     unless my $dschema = $self->get("/definitions/$name");
    local $self->{inside_discriminator} = 1;    # prevent recursion
    return $self->_validate($data, $path, $dschema);
  }

  return (
    $self->_validate_type_object_min_max($_[1], $path, $schema),
    $self->_validate_type_object_dependencies($_[1], $path, $schema),
    $self->_validate_type_object_properties($_[1], $path, $schema),
  );
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

  $parameters = $schema->parameters_for_request([$method, $path]);

Finds all the request parameters defined in the schema, including inherited
parameters. Returns C<undef> if the C<$path> and C<$method> cannot be found.

Example return value:

  [
    {in => "query", name => "q"},
    {in => "body", name => "body", accepts => ["application/json"]},
  ]

The return value MUST not be mutated.

=head2 parameters_for_response

  $array_ref = $schema->parameters_for_response([$method, $path, $status]);

Finds the response parameters defined in the schema. Returns C<undef> if the
C<$path>, C<$method> and C<$status> cannot be found. Will default to the
"default" response definition if C<$status> could not be found and "default"
exists.

Example return value:

  [
    {in => "header", name => "X-Foo"},
    {in => "body", name => "body", accepts => ["application/json"]},
  ]

The return value MUST not be mutated.

=head2 validate_request

  @errors = $schema->validate_request([$method, $path], \%req);

This method can be used to validate a HTTP request. C<%req> should contain
key/value pairs representing the request parameters. Example:

  %req = (
    body => sub {
      my ($param_name, $param_for_request) = shift;
      return {exists => 1, value => {email => "..."}};
    },
    formData => {email => "..."},
    header => {"X-Request-Base" => "..."},
    path => {id => "..."},
    query => {limit => 42},
  );

"formData", "header", "path" and "query" can be either a hash-ref, a hash-like
object or a code ref, while "body" MUST be a code ref. The return value from
the code ref will get mutated, making it possible to check if an individual
parameter was validated or not.

  # Before: "exists" and "value" must be present
  my @evaluated;
  $req{query} =  sub { push @evaluated, {exists => 1, value => 42}, return $evaluated[-1] };

  # Validate
  $schema->validate_request(get => "/user"], \%req);

  # After: "in", "name" and "valid" are added
  $evaluated[-1] ==> {exists => 1, value => 42, in => "query", name => "foo", valid => 1};

A plain hash-ref will I</not> get mutated.

=head2 validate_response

  @errors = $schema->validate_response([$method, $path, $status], \%res);

This method can be used to validate a HTTP response. C<%res> should contain
key/value pairs representing the response parameters. Example:

  %res = (
    body => sub {
      my ($param_name, $param_for_response) = shift;
      return {exists => 1, value => {email => "..."}};
    },
    header => {"Location" => "..."},
  );

C<%res> follows the same rules as C<%req> in L</validate_request>.

=head1 SEE ALSO

L<JSON::Validator>, L<Mojolicious::Plugin::OpenAPI>,
L<http://openapi-specification-visual-documentation.apihandyman.io/>

=cut
