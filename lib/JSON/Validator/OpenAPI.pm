package JSON::Validator::OpenAPI;
use Mojo::Base 'JSON::Validator';
use Scalar::Util ();

use constant DEBUG => $ENV{JSON_VALIDATOR_DEBUG} || 0;
use constant IV_SIZE           => eval 'require Config;$Config::Config{ivsize}';
use constant SPECIFICATION_URL => 'http://swagger.io/v2/schema.json';

my %COLLECTION_RE = (pipes => qr{\|}, csv => qr{,}, ssv => qr{\s}, tsv => qr{\t});

has _json_validator => sub { state $v = JSON::Validator->new; };

sub validate_input {
  my $self = shift;
  local $self->{validate_input} = 1;
  local $self->{root}           = $self->schema;
  $self->validate(@_);
}

sub validate_request {
  my ($self, $c, $schema, $input) = @_;
  my (%cache, @errors);

  for my $p (@{$schema->{parameters} || []}) {
    my ($in, $name, $type) = @$p{qw(in name type)};
    my ($exists, $value);

    if ($in eq 'path') {
      $value = $self->_extract_request_parameter($c, $in);
      $exists = length $value if defined $value;
    }
    elsif ($in eq 'formData' and $type eq 'file') {
      $value = $c->req->upload($name);
      $exists = $value ? 1 : 0;
    }
    else {
      $value  = $cache{$in} ||= $self->_extract_request_parameter($c, $in);
      $exists = exists $value->{$name};
      $value  = $value->{$name};
    }

    if (ref $p->{items} eq 'HASH' and $p->{collectionFormat}) {
      $value = $self->_coerce_by_collection_format($value, $p);
    }

    if ($type and defined($value //= $p->{default})) {
      if (($type eq 'integer' or $type eq 'number') and $value =~ /^-?\d/) {
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
      $self->_set_request_parameter($c, $p, $value);
    }
    elsif (!$exists and exists $p->{default}) {
      $self->_set_request_parameter($c, $p, $value);
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

sub _extract_request_parameter {
  my ($self, $c, $in) = @_;

  return $c->req->url->query->to_hash  if $in eq 'query';
  return $c->match->stack->[-1]        if $in eq 'path';
  return $c->req->body_params->to_hash if $in eq 'formData';
  return $c->req->headers->to_hash     if $in eq 'header';
  return $c->req->json                 if $in eq 'body';
  return {};
}

sub _set_request_parameter {
  my ($self, $c, $p, $value) = @_;
  my ($in, $name) = @$p{qw(in name)};

  if ($in eq 'query') {
    $c->req->url->query([$name => $value]);
    $c->req->params->merge($name => $value);
  }
  elsif ($in eq 'path') {
    $c->match->stack->[-1]{$name} = $value;
    $c->stash($name => $value);
  }
  elsif ($in eq 'formData') {
    $c->req->params->merge($name => $value);
    $c->req->body_params->merge($name => $value);
  }
  elsif ($in eq 'header') {
    $c->req->headers->header($name => $value);
  }
  elsif ($in eq 'body') {
    return;    # no need to write body back
  }
  else {
    die
      "Cannot set default for $in => $name. Please submit a ticket here: https://github.com/jhthorsen/mojolicious-plugin-openapi";
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
  my $headers = $c->res->headers;
  my $input   = $headers->to_hash(1);
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
      $headers->header($name => $input->{$name}[0] ? 'true' : 'false')
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

  $formats->{byte}   = \&_is_byte_string;
  $formats->{date}   = \&_is_date;
  $formats->{double} = \&Scalar::Util::looks_like_number;
  $formats->{float}  = \&Scalar::Util::looks_like_number;
  $formats->{int32}  = sub { _is_number($_[0], 'l'); };
  $formats->{int64}  = IV_SIZE >= 8 ? sub { _is_number($_[0], 'q'); } : sub {1};
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

L<JSON::Validator::OpenAPI> is currently EXPERIMENTAL. Let me know if you are
interested in using this class with another framework than L<Mojolicious>.

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

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
