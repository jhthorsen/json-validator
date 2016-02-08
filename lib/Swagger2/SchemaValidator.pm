package Swagger2::SchemaValidator;
use Mojo::Base 'JSON::Validator';
use Scalar::Util ();

use constant IV_SIZE => eval 'require Config;$Config::Config{ivsize}';

our %COLLECTION_RE = (pipes => qr{\|}, csv => qr{,}, ssv => qr{\s}, tsv => qr{\t});

sub validate_input {
  my $self = shift;
  local $self->{validate_input} = 1;
  $self->validate(@_);
}

sub _validate_type_array {
  my ($self, $data, $path, $schema) = @_;

  if (ref $data eq 'ARRAY' and ref $schema->{items} eq 'HASH' and $schema->{items}{collectionFormat}) {
    $self->_coerce_by_collection_format($data, $schema->{items});
  }

  return $self->SUPER::_validate_type_array(@_[1, 2, 3]);
}

# always valid
sub _validate_type_file { }

sub _validate_type_object {
  return shift->SUPER::_validate_type_object(@_) unless $_[0]->{validate_input};

  my ($self, $data, $path, $schema) = @_;
  my $properties = $schema->{properties} || {};
  my (%ro, @e);

  for my $p (keys %$properties) {
    next unless $properties->{$p}{readOnly};
    push @e, JSON::Validator::E("$path/$p", "Read-only.") if exists $data->{$p};
    $ro{$p} = 1;
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

  return $formats;
}

sub _coerce_by_collection_format {
  my ($self, $data, $schema) = @_;
  my $re = $COLLECTION_RE{$schema->{collectionFormat}} || ',';
  my $type = $schema->{type} || '';

  for my $i (0 .. @$data - 1) {
    my @d = split /$re/, $data->[$i];
    $data->[$i] = ($type eq 'integer' or $type eq 'number') ? [map { $_ + 0 } @d] : \@d;
  }
}

sub _is_byte_string { $_[0] =~ /^[A-Za-z0-9\+\/\=]+$/o }
sub _is_date        { $_[0] =~ /^(\d+)-(\d+)-(\d+)$/o }

sub _is_number {
  return unless $_[0] =~ /^-?\d+(\.\d+)?$/o;
  return $_[0] eq unpack $_[1], pack $_[1], $_[0];
}

1;

=encoding utf8

=head1 NAME

Swagger2::SchemaValidator - Sub class of JSON::Validator

=head1 DESCRIPTION

This class is used to validate Swagger specification. It is a sub class of
L<JSON::Validator> and adds some extra functionality specific for L<Swagger2>.

=head1 ATTRIBUTES

L<Swagger2::SchemaValidator> inherits all attributes from L<JSON::Validator>.

=head2 formats

Swagger support the same formats as L<Swagger2::SchemaValidator>, but adds the
following to the set:

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

L<Swagger2::SchemaValidator> inherits all attributes from L<JSON::Validator>.

=head2 validate_input

This method will make sure "readOnly" is taken into account, when validating
data sent to your API.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014-2015, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
