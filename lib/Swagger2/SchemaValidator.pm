package Swagger2::SchemaValidator;

=head1 NAME

Swagger2::SchemaValidator - Sub class of JSON::Validator

=head1 DESCRIPTION

This class is used to validate Swagger specification. It is a sub class of
L<JSON::Validator> and adds some extra functionality specific for L<Swagger2>.

=cut

use Mojo::Base 'JSON::Validator';
use Scalar::Util ();

use constant IV_SIZE => eval 'require Config;$Config::Config{ivsize}';

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

=cut

# always valid
sub _validate_type_file { }

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

sub _is_byte_string { $_[0] =~ /^[A-Za-z0-9\+\/\=]+$/; }
sub _is_date        { $_[0] =~ qr/^(\d+)-(\d+)-(\d+)$/io; }

sub _is_number {
  return unless $_[0] =~ /^-?\d+(\.\d+)?$/;
  return $_[0] eq unpack $_[1], pack $_[1], $_[0];
}

=head1 METHODS

L<Swagger2::SchemaValidator> inherits all attributes from L<JSON::Validator>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014-2015, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
