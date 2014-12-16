package Swagger2::SchemaValidator;

=head1 NAME

Swagger2::SchemaValidator - Validate JSON schemas

=head1 DESCRIPTION

L<Swagger2::SchemaValidator> is a class for validating JSON schemas.

The validation process is supposed to be compatible with
L<draft 4|https://github.com/json-schema/json-schema/tree/master/draft-04>
of the JSON schema specification. Please submit a
L<bug report|https://github.com/jhthorsen/swagger2/issues>
if it is not.

=head1 SYNOPSIS

  use Swagger2::SchemaValidator;
  my $validator = Swagger2::SchemaValidator->new;

  @errors = $validator->validate($data, $schema);

Example:

  warn $validator->validate(
    {
      nick => "batman",
    },
    {
      type => "object",
      properties => {
        nick => {type => "string", minLength => 3, maxLength => 10, pattern => qr{^\w+$} }
      },
    },
  );

=head1 SEE ALSO

=over 4

=item * L<http://spacetelescope.github.io/understanding-json-schema/index.html>

=item * L<http://jsonary.com/documentation/json-schema/>

=item * L<https://github.com/json-schema/json-schema/>

=back

=cut

use Mojo::Base -base;
use Mojo::Util;
use B;
use Scalar::Util;
use constant TODO => 0;

use constant VALIDATE_HOSTNAME      => eval 'require Data::Validate::Domain;1';
use constant VALIDATE_IP            => eval 'require Data::Validate::IP;1';
use constant IV_SIZE                => eval 'require Config;$Config::Config{ivsize}';
use constant WARN_ON_MISSING_FORMAT => $ENV{SWAGGER2_WARN_ON_MISSING_FORMAT} ? 1 : 0;

sub E {
  bless {path => $_[0] || '/', message => $_[1]}, 'Swagger2::SchemaValidator::Error';
}

sub S {
  Mojo::Util::md5_sum(Data::Dumper->new([@_])->Sortkeys(1)->Useqq(1)->Dump);
}

sub _cmp {
  return undef if !defined $_[0] or !defined $_[1];
  return "$_[3]=" if $_[2] and $_[0] >= $_[1];
  return $_[3] if $_[0] > $_[1];
  return "";
}

sub _expected {
  my $type = _guess($_[1]);
  return "Expected $_[0] - got different $type." if $_[0] =~ /\b$type\b/;
  return "Expected $_[0] - got $type.";
}

sub _guess {
  local $_ = $_[0];
  my $ref     = ref;
  my $blessed = Scalar::Util::blessed($_[0]);
  return 'object' if $ref eq 'HASH';
  return lc $ref if $ref and !$blessed;
  return 'null' if !defined;
  return 'boolean' if $blessed and "$_" eq "1" or "$_" eq "0";
  return 'integer' if /^\d+$/;
  return 'number' if B::svref_2object(\$_)->FLAGS & (B::SVp_IOK | B::SVp_NOK) and 0 + $_ eq $_ and $_ * 0 == 0;
  return $blessed || 'string';
}

sub _is_byte_string {
  $_[0] =~ /^[A-Za-z0-9\+\/\=]+$/;
}

sub _is_domain {
  warn "Data::Validate::Domain is not installed";
  return;
}

sub _is_ipv4 {
  my (@octets) = $_[0] =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
  return 4 == grep { $_ >= 0 && $_ <= 255 && $_ !~ /^0\d{1,2}$/ } @octets;
}

sub _is_ipv6 {
  warn "Data::Validate::IP is not installed";
  return;
}

sub _is_number {
  return unless $_[0] =~ /^-?\d+(\.\d+)?$/;
  return $_[0] eq unpack $_[1], pack $_[1], $_[0];
}

sub _path {
  local $_ = $_[1];
  s!~!~0!g;
  s!/!~1!g;
  "$_[0]/$_";
}

my $DATE_RFC3339_RE      = qr/^(\d+)-(\d+)-(\d+)$/io;
my $DATE_TIME_RFC3339_RE = qr/^(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+(?:\.\d+)?)(?:Z|([+-])(\d+):(\d+))?$/io;

my $EMAIL_RFC5322_RE = do {
  my $atom           = qr;[a-zA-Z0-9_!#\$\%&'*+/=?\^`{}~|\-]+;o;
  my $quoted_string  = qr/"(?:\\[^\r\n]|[^\\"])*"/o;
  my $domain_literal = qr/\[(?:\\[\x01-\x09\x0B-\x0c\x0e-\x7f]|[\x21-\x5a\x5e-\x7e])*\]/o;
  my $dot_atom       = qr/$atom(?:[.]$atom)*/o;
  my $local_part     = qr/(?:$dot_atom|$quoted_string)/o;
  my $domain         = qr/(?:$dot_atom|$domain_literal)/o;

  qr/$local_part[@]$domain/o;
};

my $URI_RFC3986_RE = qr!^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?!o;

=head1 ATTRIBUTES

=head2 formats

  $hash_ref = $self->formats;
  $self = $self->formats(\%hash);

Holds a hash-ref, where the keys are supported JSON type "formats", and
the values holds a code block which can validate a given format.

Note! The modules mentioned below are optional.

=over 4

=item * byte

A padded, base64-encoded string of bytes, encoded with a URL and filename safe
alphabet. Defined by RFC4648.

=item * date

An RFC3339 date in the format YYYY-MM-DD

=item * date-time

An RFC3339 timestamp in UTC time. This is formatted as
"YYYY-MM-DDThh:mm:ss.fffZ". The milliseconds portion (".fff") is optional

=item * double

Cannot test double values with higher precision then what
the "number" type already provides.

=item * email

Validated against the RFC5322 spec.

=item * float

Will always be true if the input is a number, meaning there is no difference
between  L</float> and L</double>. Patches are welcome.

=item * hostname

Will be validated using L<Data::Validate::Domain> if installed.

=item * int32

A signed 32 bit integer.

=item * int64

A signed 64 bit integer. Note: This check is only available if Perl is
compiled to use 64 bit integers.

=item * ipv4

Will be validated using L<Data::Validate::IP> if installed or
fall back to a plain IPv4 IP regex.

=item * ipv6

Will be validated using L<Data::Validate::IP> if installed.

=item * uri

Validated against the RFC3986 spec.

=back

=cut

has formats => sub {
  +{
    'byte'      => \&_is_byte_string,
    'date'      => sub { $_[0] =~ $DATE_RFC3339_RE; },
    'date-time' => sub { $_[0] =~ $DATE_TIME_RFC3339_RE; },
    'double'    => sub {1},
    'float'     => sub {1},
    'email'     => sub { $_[0] =~ $EMAIL_RFC5322_RE; },
    'hostname'  => VALIDATE_HOSTNAME ? \&Data::Validate::Domain::is_domain : \&_is_domain,
    'int32'     => sub { _is_number($_[0], 'l'); },
    'int64'     => IV_SIZE >= 8 ? sub { _is_number($_[0], 'q'); } : sub {1},
    'ipv4' => VALIDATE_IP ? \&Data::Validate::IP::is_ipv4 : \&_is_ipv4,
    'ipv6' => VALIDATE_IP ? \&Data::Validate::IP::is_ipv6 : \&_is_ipv6,
    'uri' => sub { $_[0] =~ $URI_RFC3986_RE; },
  };
};

=head1 METHODS

=head2 validate

  @errors = $self->validate($data, $schema);

Validates C<$data> against a given JSON C<$schema>. C<@errors> will
contain objects with containing the validation errors. It will be
empty on success.

Example error element:

  bless {
    message => "Some description",
    path => "/json/path/to/node",
  }, "Swagger2::SchemaValidator::Error"

The error objects are always true in boolean context and will stringify. The
stringification format is subject to change.

=cut

sub validate {
  my ($self, $data, $schema) = @_;

  return $self->_validate($data, '', $schema);
}

sub _validate {
  my ($self, $data, $path, $schema) = @_;
  my ($type) = (map { $schema->{$_} } grep { $schema->{$_} } qw( type allOf anyOf oneOf not ))[0] || 'any';
  my $check_all = grep { $schema->{$_} } qw( allOf oneOf not );
  my @errors;

  if ($schema->{disallow}) {
    die 'TODO: No support for disallow.';
  }

  #$SIG{__WARN__} = sub { Carp::confess(Data::Dumper::Dumper($schema)) };

  for my $t (ref $type eq 'ARRAY' ? @$type : ($type)) {
    $t //= 'null';
    if (ref $t eq 'HASH') {
      push @errors, [$self->_validate($data, $path, $t)];
      return if !$check_all and !@{$errors[-1]};    # valid
    }
    elsif (my $code = $self->can(sprintf '_validate_type_%s', $t)) {
      push @errors, [$self->$code($data, $path, $schema)];
      return if !$check_all and !@{$errors[-1]};    # valid
    }
    else {
      return E $path, "Cannot validate type '$t'";
    }
  }

  if (TODO and $schema->{not}) {
    return if grep {@$_} @errors;
    return E $path, "Should not match.";
  }
  if ($schema->{oneOf}) {
    my $n = grep { @$_ == 0 } @errors;
    return if $n == 1;    # one match
    return E $path, "Expected only one to match." if $n == @errors;
  }

  if (@errors > 1) {
    my %err;
    for my $i (0 .. @errors - 1) {
      for my $e (@{$errors[$i]}) {
        if ($e->{message} =~ m!Expected ([^\.]+)\ - got ([^\.]+)\.!) {
          push @{$err{$e->{path}}}, [$i, $e->{message}, $1, $2];
        }
        else {
          push @{$err{$e->{path}}}, [$i, $e->{message}];
        }
      }
    }
    unshift @errors, [];
    for my $p (sort keys %err) {
      my %uniq;
      my @e = grep { !$uniq{$_->[1]}++ } @{$err{$p}};
      if (@e == grep { defined $_->[2] } @e) {
        push @{$errors[0]}, E $p, sprintf 'Expected %s - got %s.', join(', ', map { $_->[2] } @e), $e[0][3];
      }
      else {
        push @{$errors[0]}, E $p, join ' ', map {"[$_->[0]] $_->[1]"} @e;
      }
    }
  }

  return @{$errors[0]};
}

sub _validate_additional_properties {
  my ($self, $data, $path, $schema) = @_;
  my $properties = $schema->{additionalProperties};
  my @errors;

  if (ref $properties eq 'HASH') {
    push @errors, $self->_validate_properties($data, $path, $schema);
  }
  elsif (!$properties) {
    my @keys = grep { $_ !~ /^(description|id|title)$/ } keys %$data;
    if (@keys) {
      local $" = ', ';
      push @errors, E $path, "Properties not allowed: @keys.";
    }
  }

  return @errors;
}

sub _validate_enum {
  my ($self, $data, $path, $schema) = @_;
  my $enum = $schema->{enum};
  my $m    = S $data;

  for my $i (@$enum) {
    return if $m eq S $i;
  }

  local $" = ', ';
  return E $path, "Not in enum list: @$enum.";
}

sub _validate_format {
  my ($self, $value, $path, $schema) = @_;
  my $code = $self->formats->{$schema->{format}};

  unless ($code) {
    warn "Format rule for '$schema->{format}' is missing" if WARN_ON_MISSING_FORMAT;
    return;
  }

  return if $code->($value);
  return E $path, "Does not match $schema->{format} format.";
}

sub _validate_pattern_properties {
  my ($self, $data, $path, $schema) = @_;
  my $properties = $schema->{patternProperties};
  my @errors;

  for my $pattern (keys %$properties) {
    my $v = $properties->{$pattern};
    for my $tk (keys %$data) {
      next unless $tk =~ /$pattern/;
      push @errors, $self->_validate(delete $data->{$tk}, _path($path, $tk), $v);
    }
  }

  return @errors;
}

sub _validate_properties {
  my ($self, $data, $path, $schema) = @_;
  my $properties = $schema->{properties};
  my $required   = $schema->{required};
  my (@errors, %required);

  if ($required and ref $required eq 'ARRAY') {
    $required{$_} = 1 for @$required;
  }

  for my $name (keys %$properties) {
    my $p = $properties->{$name};
    if (exists $data->{$name}) {
      my $v = delete $data->{$name};
      push @errors, $self->_validate_enum($v, $path, $p) if $p->{enum};
      push @errors, $self->_validate($v, _path($path, $name), $p);
    }
    elsif ($p->{default}) {
      $data->{$name} = $p->{default};
    }
    elsif ($required{$name}) {
      push @errors, E _path($path, $name), "Missing property.";
    }
    elsif ($p->{required} and ref $p->{required} eq '') {
      push @errors, E _path($path, $name), "Missing property.";
    }
  }

  return @errors;
}

sub _validate_type_any {
  return;
}

sub _validate_type_array {
  my ($self, $data, $path, $schema) = @_;
  my @errors;

  if (ref $data ne 'ARRAY') {
    return E $path, _expected(array => $data);
  }

  $data = [@$data];

  if (defined $schema->{minItems} and $schema->{minItems} > @$data) {
    push @errors, E $path, sprintf 'Not enough items: %s/%s.', int @$data, $schema->{minItems};
  }
  if (defined $schema->{maxItems} and $schema->{maxItems} < @$data) {
    push @errors, E $path, sprintf 'Too many items: %s/%s.', int @$data, $schema->{maxItems};
  }
  if ($schema->{uniqueItems}) {
    my %uniq;
    for (@$data) {
      next if !$uniq{S($_)}++;
      push @errors, E $path, 'Unique items required.';
      last;
    }
  }
  if (ref $schema->{items} eq 'ARRAY') {
    my $additional_items = $schema->{additionalItems} // 1;
    my @v = @{$schema->{items}};

    if ($additional_items) {
      push @v, $a while @v < @$data;
    }

    if (@v == @$data) {
      for my $i (0 .. @v - 1) {
        push @errors, $self->_validate($data->[$i], "$path/$i", $v[$i]);
      }
    }
    elsif (!$additional_items) {
      push @errors, E $path, sprintf "Invalid number of items: %s/%s.", int(@$data), int(@v);
    }
  }
  elsif (ref $schema->{items} eq 'HASH') {
    for my $i (0 .. @$data - 1) {
      if ($schema->{items}{properties}) {
        my $input = ref $data->[$i] eq 'HASH' ? {%{$data->[$i]}} : $data->[$i];
        push @errors, $self->_validate_properties($input, "$path/$i", $schema->{items});
      }
      else {
        push @errors, $self->_validate($data->[$i], "$path/$i", $schema->{items});
      }
    }
  }

  return @errors;
}

sub _validate_type_boolean {
  my ($self, $value, $path, $schema) = @_;

  return if defined $value and ("$value" eq "1" or "$value" eq "0");
  return E $path, _expected(boolean => $value);
}

sub _validate_type_integer {
  my ($self, $value, $path, $schema) = @_;
  my @errors = $self->_validate_type_number($value, $path, $schema, 'integer');

  return @errors if @errors;
  return if $value =~ /^-?\d+$/;
  return E $path, "Expected integer - got number.";
}

sub _validate_type_null {
  my ($self, $value, $path, $schema) = @_;

  return E $path, 'Not null.' if defined $value;
  return;
}

sub _validate_type_number {
  my ($self, $value, $path, $schema, $expected) = @_;
  my @errors;

  $expected ||= 'number';

  if (!defined $value or ref $value) {
    return E $path, _expected($expected => $value);
  }
  unless (B::svref_2object(\$value)->FLAGS & (B::SVp_IOK | B::SVp_NOK) and 0 + $value eq $value and $value * 0 == 0) {
    return E $path, "Expected $expected - got string.";
  }

  if ($schema->{format}) {
    push @errors, $self->_validate_format($value, $path, $schema);
  }
  if (my $e = _cmp($schema->{minimum}, $value, $schema->{exclusiveMinimum}, '<')) {
    push @errors, E $path, "$value $e minimum($schema->{minimum})";
  }
  if (my $e = _cmp($value, $schema->{maximum}, $schema->{exclusiveMaximum}, '>')) {
    push @errors, E $path, "$value $e maximum($schema->{maximum})";
  }
  if (my $d = $schema->{multipleOf}) {
    unless (int($value / $d) == $value / $d) {
      push @errors, E $path, "Not multiple of $d.";
    }
  }

  return @errors;
}

sub _validate_type_object {
  my ($self, $data, $path, $schema) = @_;
  my @errors;

  if (ref $data ne 'HASH') {
    return E $path, _expected(object => $data);
  }

  # make sure _validate_xxx() does not mess up original $data
  $data = {%$data};

  if (defined $schema->{maxProperties} and $schema->{maxProperties} < keys %$data) {
    push @errors, E $path, sprintf 'Too many properties: %s/%s.', int(keys %$data), $schema->{maxProperties};
  }
  if (defined $schema->{minProperties} and $schema->{minProperties} > keys %$data) {
    push @errors, E $path, sprintf 'Not enough properties: %s/%s.', int(keys %$data), $schema->{minProperties};
  }
  if ($schema->{properties}) {
    push @errors, $self->_validate_properties($data, $path, $schema);
  }
  if ($schema->{patternProperties}) {
    push @errors, $self->_validate_pattern_properties($data, $path, $schema);
  }
  if (exists $schema->{additionalProperties}) {
    push @errors, $self->_validate_additional_properties($data, $path, $schema);
  }

  return @errors;
}

sub _validate_type_string {
  my ($self, $value, $path, $schema) = @_;
  my @errors;

  if (!defined $value or ref $value) {
    return E $path, _expected(string => $value);
  }
  if (B::svref_2object(\$value)->FLAGS & (B::SVp_IOK | B::SVp_NOK) and 0 + $value eq $value and $value * 0 == 0) {
    return E $path, "Expected string - got number.";
  }
  if ($schema->{format}) {
    push @errors, $self->_validate_format($value, $path, $schema);
  }
  if (defined $schema->{maxLength}) {
    if (length($value) > $schema->{maxLength}) {
      push @errors, E $path, sprintf "String is too long: %s/%s.", length($value), $schema->{maxLength};
    }
  }
  if (defined $schema->{minLength}) {
    if (length($value) < $schema->{minLength}) {
      push @errors, E $path, sprintf "String is too short: %s/%s.", length($value), $schema->{minLength};
    }
  }
  if (defined $schema->{pattern}) {
    my $p = $schema->{pattern};
    unless ($value =~ /$p/) {
      push @errors, E $path, "String does not match '$p'";
    }
  }

  return @errors;
}

package    # hide from
  Swagger2::SchemaValidator::Error;

use overload q("") => sub { sprintf '%s: %s', @{$_[0]}{qw( path message )} }, bool => sub {1}, fallback => 1;
sub TO_JSON { {message => $_[0]->{message}, path => $_[0]->{path}} }

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
