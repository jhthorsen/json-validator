package JSON::Validator::OpenAPI;
use Carp ();
use Mojo::Base 'JSON::Validator';
use Mojo::Util qw(deprecated monkey_patch);
use Scalar::Util ();

use constant DEBUG => $ENV{JSON_VALIDATOR_DEBUG} || 0;
use constant IV_SIZE           => eval 'require Config;$Config::Config{ivsize}';
use constant SPECIFICATION_URL => 'http://swagger.io/v2/schema.json';

my %COLLECTION_RE = (pipes => qr{\|}, csv => qr{,}, ssv => qr{\s}, tsv => qr{\t});

has _json_validator => sub { state $v = JSON::Validator->new; };

sub load_and_validate_schema {
  my ($self, $spec, $args) = @_;
  my $openapi = $self->new(%$self)->schema($args->{schema} || SPECIFICATION_URL);
  my ($api_spec, @errors);

  # 1. first check if $ref is in the right place,
  # 2. then check if the spec is correct
  for my $r (sub { }, undef) {
    next if $r and $args->{allow_invalid_ref};
    my $jv = $self->new(%$self);
    $jv->resolver($r) if $r;
    $api_spec = $jv->schema($spec)->schema;
    @errors   = $openapi->coerce($jv->coerce)->validate($api_spec->data);
    Carp::confess(join "\n", "Invalid schema:", @errors) if @errors;
  }

  if (my $class = $args->{version_from_class}) {
    if (UNIVERSAL::can($class, 'VERSION') and $class->VERSION) {
      $api_spec->data->{info}{version} = $class->VERSION;
    }
  }

  warn "[OpenAPI] Loaded $spec\n" if DEBUG;
  $self->{schema} = $api_spec;
  $self;
}

# deprecated
sub load_and_validate_spec { goto &load_and_validate_schema }

sub validate_input {
  my $self = shift;
  local $self->{validate_input} = 1;
  local $self->{root}           = $self->schema;
  $self->validate(@_);
}

sub validate_request {
  my ($self, $c, $schema, $input) = @_;
  my @errors;

  for my $p (@{$schema->{parameters} || []}) {
    my ($in, $name, $type) = @$p{qw(in name type)};
    my ($exists, $value);

    if ($in eq 'body') {
      $value = $self->_get_request_data($c, $in);
      $exists = length $value if defined $value;
    }
    elsif ($in eq 'formData' and $type eq 'file') {
      $value = $self->_get_request_uploads($c, $name)->[-1];
      $exists = $value ? 1 : 0;
    }
    else {
      $value  = $self->_get_request_data($c, $in);
      $exists = exists $value->{$name};
      $value  = $value->{$name};
    }

    if (defined $value and ref $p->{items} eq 'HASH' and $p->{collectionFormat}) {
      $value = $self->_coerce_by_collection_format($value, $p);
    }

    if ($type and defined($value //= $p->{default})) {
      if ($type ne 'array' and ref $value eq 'ARRAY') {
        $value = $value->[-1];
      }
      if (($type eq 'integer' or $type eq 'number') and Scalar::Util::looks_like_number($value)) {
        $value += 0;
      }
      elsif ($type eq 'boolean') {
        $value = (!$value or $value eq 'false') ? Mojo::JSON->false : Mojo::JSON->true;
      }
    }

    if (my @e = $self->_validate_request_value($p, $name => $value)) {
      push @errors, @e;
    }
    elsif ($exists or exists $p->{default}) {
      $input->{$name} = $value;
      $self->_set_request_data($c, $in, $name => $value);
    }
    elsif (!$exists and exists $p->{default}) {
      $self->_set_request_data($c, $in, $name => $value);
    }
  }

  return @errors;
}

sub validate_response {
  my ($self, $c, $schema, $status, $data) = @_;
  my @errors;

  if (my $blueprint = $schema->{responses}{$status} || $schema->{responses}{default}) {
    push @errors, $self->_validate_response_headers($c, $blueprint->{headers})
      if $blueprint->{headers};

    if ($blueprint->{'x-json-schema'}) {
      warn "[JSON::Validator::OpenAPI] Validate using x-json-schema\n" if DEBUG;
      push @errors, $self->_json_validator->validate($data, $blueprint->{'x-json-schema'});
    }
    elsif ($blueprint->{schema}) {
      warn "[JSON::Validator::OpenAPI] Validate using schema\n" if DEBUG;
      push @errors, $self->validate($data, $blueprint->{schema});
    }
  }
  else {
    push @errors, JSON::Validator::E('/' => "No responses rules defined for status $status.");
  }

  return @errors;
}

{
  my @proxy_methods = qw(
    _get_request_uploads
    _get_request_data
    _set_request_data
    _get_response_data
    _set_response_data
  );

  for my $method (@proxy_methods) {
    monkey_patch(__PACKAGE__,
      $method => sub {
        deprecated "Using JSON::Validator::OpenAPI directly is DEPRECATED."
          . " For the Mojolicious-specific methods use JSON::Validator::OpenAPI::Mojolicious";

        require JSON::Validator::OpenAPI::Mojolicious;
        my $self = shift;
        bless $self, 'JSON::Validator::OpenAPI::Mojolicious';
        return $self->$method(@_);
      }
    );
  }
}

sub _validate_request_value {
  my ($self, $p, $name, $value) = @_;
  my $type = $p->{type} || 'object';
  my @e;

  return if !defined $value and !JSON::Validator::_is_true($p->{required});

  my $in     = $p->{in};
  my $schema = {
    properties => {$name => $p->{'x-json-schema'} || $p->{schema} || $p},
    required => [$p->{required} ? ($name) : ()]
  };

  if ($in eq 'body') {
    warn "[JSON::Validator::OpenAPI] Validate $in $name\n" if DEBUG;
    if ($p->{'x-json-schema'}) {
      return $self->_json_validator->validate({$name => $value}, $schema);
    }
    else {
      return $self->validate_input({$name => $value}, $schema);
    }
  }
  elsif (defined $value) {
    warn "[JSON::Validator::OpenAPI] Validate $in $name=$value\n" if DEBUG;
    return $self->validate_input({$name => $value}, $schema);
  }
  else {
    warn "[JSON::Validator::OpenAPI] Validate $in $name=undef\n" if DEBUG;
    return $self->validate_input({$name => $value}, $schema);
  }

  return;
}

sub _validate_response_headers {
  my ($self, $c, $schema) = @_;
  my $input = $self->_get_response_data($c, 'header');
  my @errors;

  for my $name (keys %$schema) {
    my $p = $schema->{$name};

    # jhthorsen: I think that the only way to make a header required,
    # is by defining "array" and "minItems" >= 1.
    if ($p->{type} eq 'array') {
      push @errors, $self->validate($input->{$name}, $p);
    }
    elsif ($input->{$name}) {
      push @errors, $self->validate($input->{$name}[0], $p);
      $self->_set_response_data($c, 'header', $name => $input->{$name}[0] ? 'true' : 'false')
        if $p->{type} eq 'boolean' and !@errors;
    }
  }

  return @errors;
}

sub _validate_type_array {
  my ($self, $data, $path, $schema) = @_;

  if (ref $schema->{items} eq 'HASH' and $schema->{items}{collectionFormat}) {
    $data = $self->_coerce_by_collection_format($data, $schema->{items});
  }

  return $self->SUPER::_validate_type_array($data, $path, $schema);
}

sub _validate_type_file {
  my ($self, $data, $path, $schema) = @_;

  if ($schema->{required} and (not defined $data or not length $data)) {
    return JSON::Validator::E($path => 'Missing property.');
  }

  return;
}

sub _validate_type_object {
  return shift->SUPER::_validate_type_object(@_) unless $_[0]->{validate_input};

  my ($self, $data, $path, $schema) = @_;
  my $properties = $schema->{properties} || {};
  my $discriminator = $schema->{discriminator};
  my (%ro, @e);

  for my $p (keys %$properties) {
    next unless $properties->{$p}{readOnly};
    push @e, JSON::Validator::E("$path/$p", "Read-only.") if exists $data->{$p};
    $ro{$p} = 1;
  }

  if ($discriminator and !$self->{inside_discriminator}) {
    my $name = $data->{$discriminator}
      or return JSON::Validator::E($path, "Discriminator $discriminator has no value.");
    my $dschema = $self->{root}->get("/definitions/$name")
      or return JSON::Validator::E($path, "No definition for discriminator $name.");
    local $self->{inside_discriminator} = 1;    # prevent recursion
    return $self->_validate($data, $path, $dschema);
  }

  local $schema->{required} = [grep { !$ro{$_} } @{$schema->{required} || []}];

  return @e, $self->SUPER::_validate_type_object($data, $path, $schema);
}

sub _build_formats {
  my $formats = shift->SUPER::_build_formats;

  $formats->{byte}     = \&_is_byte_string;
  $formats->{date}     = \&_is_date;
  $formats->{double}   = \&Scalar::Util::looks_like_number;
  $formats->{float}    = \&Scalar::Util::looks_like_number;
  $formats->{int32}    = sub { _is_number($_[0], 'l'); };
  $formats->{int64}    = IV_SIZE >= 8 ? sub { _is_number($_[0], 'q'); } : sub {1};
  $formats->{password} = sub {1};
  $formats;
}

sub _coerce_by_collection_format {
  my ($self, $data, $schema) = @_;
  my $type = ($schema->{items} ? $schema->{items}{type} : $schema->{type}) || '';

  if ($schema->{collectionFormat} eq 'multi') {
    $data = [$data] unless ref $data eq 'ARRAY';
    @$data = map { $_ + 0 } @$data if $type eq 'integer' or $type eq 'number';
    return $data;
  }

  my $re = $COLLECTION_RE{$schema->{collectionFormat}} || ',';
  my $single = ref $data eq 'ARRAY' ? 0 : ($data = [$data]);

  for my $i (0 .. @$data - 1) {
    my @d = split /$re/, ($data->[$i] // '');
    $data->[$i] = ($type eq 'integer' or $type eq 'number') ? [map { $_ + 0 } @d] : \@d;
  }

  return $single ? $data->[0] : $data;
}

sub _confess_invalid_in {
  Carp::confess(
    "Unsupported \$in: $_[0]. Please report at https://github.com/jhthorsen/json-validator");
}

sub _is_byte_string { $_[0] =~ /^[A-Za-z0-9\+\/\=]+$/ }
sub _is_date        { $_[0] =~ /^(\d+)-(\d+)-(\d+)$/ }

sub _is_number {
  return unless $_[0] =~ /^-?\d+(\.\d+)?$/;
  return $_[0] eq unpack $_[1], pack $_[1], $_[0];
}

1;

=encoding utf8

=head1 NAME

JSON::Validator::OpenAPI - OpenAPI is both a subset and superset of JSON Schema

=head1 DESCRIPTION

L<JSON::Validator::OpenAPI> can validate Open API (also known as "Swagger")
requests and responses that is passed through a L<Mojolicious> powered web
application.

=head1 ATTRIBUTES

L<JSON::Validator::OpenAPI> inherits all attributes from L<JSON::Validator>.

=head2 formats

Open API support the same formats as L<JSON::Validator>, but adds the following
to the set:

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

=head1 METHODS

L<JSON::Validator::OpenAPI> inherits all attributes from L<JSON::Validator>.

=head2 load_and_validate_schema

  $self = $self->load_and_validate_schema($schema, \%args);

Will load and validate C<$schema> against the OpenAPI specification. C<$schema>
can be anything L<JSON::Validator/schema> accepts. The expanded specification
will be stored in L<JSON::Validator/schema> on success. See
L<JSON::Validator/schema> for the different version of C<$url> that can be
accepted.

C<%args> can be used to further instruct the expansion and validation process:

=over 2

=item * allow_invalid_ref

Setting this to a true value, will disable the first pass. This is useful if
you don't like the restrictions set by OpenAPI, regarding where you can use
C<$ref> in your specification.

=item * version_from_class

Setting this to a module/class name will use the version number from the
class and overwrite the version in the specification:

  {
    "info": {
      "version": "1.00" // <-- this value
    }
  }

=back

The validation is done with a two pass process:

=over 2

=item 1.

First it will check if the C<$ref> is only specified on the correct places.
This can be disabled by setting L</allow_invalid_ref> to a true value.

=item 2.

Validate the expanded version of the spec, (without any C<$ref>) against the
OpenAPI schema.

=back

=head2 validate_input

  @errors = $self->validate_input($data, $schema);

This method will make sure "readOnly" is taken into account, when validating
data sent to your API.

=head2 validate_request

  @errors = $self->validate_request($c, $schema, \%input);

Takes an L<Mojolicious::Controller> and a schema definition and returns a list
of errors, if any. Validated input parameters are moved into the C<%input>
hash.

=head2 validate_response

  @errors = $self->validate_response($c, $schema, $status, $data);

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014-2015, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 SEE ALSO

L<JSON::Validator>.

L<http://openapi-specification-visual-documentation.apihandyman.io/>

=cut
