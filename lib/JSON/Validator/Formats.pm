package JSON::Validator::Formats;
use Mojo::Base -strict;

use Scalar::Util 'looks_like_number';

require Time::Local;

use constant DATA_VALIDATE_DOMAIN => eval 'require Data::Validate::Domain;1';
use constant DATA_VALIDATE_IP     => eval 'require Data::Validate::IP;1';
use constant IV_SIZE              => eval 'require Config;$Config::Config{ivsize}';
use constant NET_IDN_ENCODE       => eval 'require Net::IDN::Encode;1';
use constant WARN_MISSING_MODULE  => $ENV{JSON_VALIDATOR_WARN} // 1;

our $IRI_TEST_NAME = 'iri-reference';

sub check_byte {
  $_[0] =~ /^[A-Za-z0-9\+\/\=]+$/ ? undef : 'Does not match byte format.';
}

sub check_date {
  my @date = $_[0] =~ m!^(\d{4})-(\d\d)-(\d\d)$!io;
  return 'Does not match date format.' unless @date;
  @date = map { s/^0+//; $_ || 0 } reverse @date;
  $date[1] -= 1;    # month are zero based
  local $@;
  return undef if eval { Time::Local::timegm(0, 0, 0, @date); 1 };
  my $err = (split / at /, $@)[0];
  $err =~ s!('-?\d+'\s|\s[\d\.]+)!!g;
  $err .= '.';
  return $err;
}

sub check_date_time {
  my @dt = $_[0] =~ m!^(\d{4})-(\d\d)-(\d\d)[T ](\d\d):(\d\d):(\d\d(?:\.\d+)?)(?:Z|([+-])(\d+):(\d+))?$!io;
  return 'Does not match date-time format.' unless @dt;
  @dt = map { s/^0//; $_ } reverse @dt[0 .. 5];
  $dt[4] -= 1;    # month are zero based
  local $@;
  return undef if eval { Time::Local::timegm(@dt); 1 };
  my $err = (split / at /, $@)[0];
  $err =~ s!('-?\d+'\s|\s[\d\.]+)!!g;
  $err .= '.';
  return $err;
}

sub check_double { _match_number(double => $_[0], '') }

sub check_duration {
  state $rfc3339_duration_re = do {
    my $num  = qr{\d+(?:[,.]\d+)?};
    my $sec  = qr/${num}S/;
    my $min  = qr/${num}M(?:$sec)?/;
    my $hour = qr/${num}H(?:$min)?/;
    my $day  = qr/${num}D(?:$hour)?/;
    my $mon  = qr/${num}M(?:$day)?/;
    my $year = qr/${num}Y(?:$mon)?/;
    my $week = qr/${num}W/;
    my $time = qr/T($hour|$min|$sec)/;
    my $date = qr/(?:$day|$mon|$year)(?:$time)?/;
    qr{^P(?:$date|$time|$week)$};
  };

  return $_[0] =~ $rfc3339_duration_re ? undef : 'Does not match duration format.';
}

sub check_email {
  state $email_rfc5322_re = do {
    my $atom           = qr;[a-zA-Z0-9_!#\$\%&'*+/=?\^`{}~|\-]+;o;
    my $quoted_string  = qr/"(?:\\[^\r\n]|[^\\"])*"/o;
    my $domain_literal = qr/\[(?:\\[\x01-\x09\x0B-\x0c\x0e-\x7f]|[\x21-\x5a\x5e-\x7e])*\]/o;
    my $dot_atom       = qr/$atom(?:[.]$atom)*/o;
    my $local_part     = qr/(?:$dot_atom|$quoted_string)/o;
    my $domain         = qr/(?:$dot_atom|$domain_literal)/o;

    qr/$local_part\@$domain/o;
  };

  return $_[0] =~ $email_rfc5322_re ? undef : 'Does not match email format.';
}

sub check_float { _match_number(float => $_[0], '') }

sub check_hostname {
  return _module_missing(hostname => 'Data::Validate::Domain') unless DATA_VALIDATE_DOMAIN;
  return undef if Data::Validate::Domain::is_hostname($_[0]);
  return 'Does not match hostname format.';
}

sub check_idn_email {
  return _module_missing('idn-email' => 'Net::IDN::Encode') unless NET_IDN_ENCODE;

  local $@;
  my $err = eval {
    my @email = split /@/, $_[0], 2;
    check_email(
      join '@',
      Net::IDN::Encode::to_ascii($email[0]        // ''),
      Net::IDN::Encode::domain_to_ascii($email[1] // ''),
    );
  };

  return $err ? 'Does not match idn-email format.' : $@ || undef;
}

sub check_idn_hostname {
  return _module_missing('idn-hostname' => 'Net::IDN::Encode') unless NET_IDN_ENCODE;

  local $@;
  my $err = eval { check_hostname(Net::IDN::Encode::domain_to_ascii($_[0])) };
  return $err ? 'Does not match idn-hostname format.' : $@ || undef;
}

sub check_int32 { _match_number(int32 => $_[0], 'l') }
sub check_int64 { _match_number(int64 => $_[0], IV_SIZE >= 8 ? 'q' : '') }

sub check_iri {
  local $IRI_TEST_NAME = 'iri';
  return 'Scheme missing.' unless $_[0] =~ m!^\w+:!;
  return check_iri_reference($_[0]);
}

sub check_iri_reference {
  return "Does not match $IRI_TEST_NAME format."
    unless $_[0] =~ m!^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?!;

  my ($scheme, $auth_host, $path, $query, $has_fragment, $fragment) = map { $_ // '' } ($2, $4, $5, $7, $8, $9);

  return 'Scheme missing.' if length $auth_host and !length $scheme;
  return 'Scheme, path or fragment are required.' unless length($scheme) + length($path) + length($has_fragment);
  return 'Scheme must begin with a letter.' if length $scheme and lc($scheme) !~ m!^[a-z][a-z0-9\+\-\.]*$!;
  return 'Invalid hex escape.'              if $_[0]                          =~ /%[^0-9a-f]/i;
  return 'Hex escapes are not complete.'    if $_[0]                          =~ /%[0-9a-f](:?[^0-9a-f]|$)/i;

  if (defined $auth_host and length $auth_host) {
    return 'Path cannot be empty and must begin with a /' unless !length $path or $path =~ m!^/!;
  }
  elsif ($path =~ m!^//!) {
    return 'Path cannot not start with //.';
  }

  return undef;
}

sub check_json_pointer {
  return !length $_[0] || $_[0] =~ m!^/! ? undef : 'Does not match json-pointer format.';
}

sub check_ipv4 {
  return undef if DATA_VALIDATE_IP and Data::Validate::IP::is_ipv4($_[0]);
  my (@octets) = $_[0] =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
  return undef if 4 == grep { $_ >= 0 && $_ <= 255 && $_ !~ /^0\d{1,2}$/ } @octets;
  return 'Does not match ipv4 format.';
}

sub check_ipv6 {
  return _module_missing(ipv6 => 'Data::Validate::IP') unless DATA_VALIDATE_IP;
  return undef if Data::Validate::IP::is_ipv6($_[0]);
  return 'Does not match ipv6 format.';
}

sub check_relative_json_pointer {
  return 'Relative JSON Pointer must start with a non-negative-integer.' unless $_[0] =~ m!^\d+!;
  return undef if $_[0]                                                               =~ m!^(\d+)#?$!;
  return 'Relative JSON Pointer must have "#" or a JSON Pointer.' unless $_[0]        =~ m!^\d+(.+)!;
  return 'Does not match relative-json-pointer format.' if check_json_pointer($1);
  return undef;
}

sub check_regex {
  eval {qr{$_[0]}} ? undef : 'Does not match regex format.';
}

sub check_time {
  my @time = $_[0] =~ m!^(\d\d):(\d\d):(\d\d(?:\.\d+)?)(?:Z|([+-])(\d+):(\d+))?$!io;
  return 'Does not match time format.' unless @time;
  @time = map { s/^0//; $_ } reverse @time[0 .. 2];
  local $@;
  return undef if eval { Time::Local::timegm(@time, 31, 11, 1947); 1 };
  my $err = (split / at /, $@)[0];
  $err =~ s!('-?\d+'\s|\s[\d\.]+)!!g;
  $err .= '.';
  return $err;
}

sub check_uri {
  return 'An URI can only only contain ASCII characters.' if $_[0] =~ m!\P{ASCII}!;
  local $IRI_TEST_NAME = 'uri';
  return check_iri_reference($_[0]);
}

sub check_uri_reference {
  local $IRI_TEST_NAME = 'uri-reference';
  return check_iri_reference($_[0]);
}

sub check_uri_template {
  return check_iri($_[0]);
}

sub check_uuid {
  state $uuid_re = do {
    my $x = qr{[0-9A-Fa-f]};
    qr{^$x$x$x$x$x$x$x$x-$x$x$x$x-[0-9]$x$x$x-$x$x$x$x-$x$x$x$x$x$x$x$x$x$x$x$x$};
  };

  return $_[0] =~ $uuid_re ? undef : 'Does not match uuid format.';
}

sub _match_number {
  my ($name, $val, $format) = @_;
  return 'Does not look like an integer' if $name =~ m!^int! and $val !~ /^-?\d+(\.\d+)?$/;
  return 'Does not look like a number.' unless looks_like_number $val;
  return undef                          unless $format;
  return undef if $val eq unpack $format, pack $format, $val;
  return "Does not match $name format.";
}

sub _module_missing {
  warn "[JSON::Validator] Cannot validate $_[0] format: $_[1] is missing" if WARN_MISSING_MODULE;
  return undef;
}

1;

=encoding utf8

=head1 NAME

JSON::Validator::Formats - Functions for validating JSON schema formats

=head1 SYNOPSIS

  use JSON::Validator::Formats;
  my $error = JSON::Validator::Formats::check_uri($str);
  die $error if $error;

  my $jv = JSON::Validator->new;
  $jv->formats({
    "date-time"     => JSON::Validator::Formats->can("check_date_time"),
    "email"         => JSON::Validator::Formats->can("check_email"),
    "hostname"      => JSON::Validator::Formats->can("check_hostname"),
    "ipv4"          => JSON::Validator::Formats->can("check_ipv4"),
    "ipv6"          => JSON::Validator::Formats->can("check_ipv6"),
    "regex"         => JSON::Validator::Formats->can("check_regex"),
    "uri"           => JSON::Validator::Formats->can("check_uri"),
    "uri-reference" => JSON::Validator::Formats->can("check_uri_reference"),
  });

=head1 DESCRIPTION

L<JSON::Validator::Formats> is a module with utility functions used by
L<JSON::Validator/formats> to match JSON Schema formats.
All functions return C<undef> for success or an error message for failure.

=head1 FUNCTIONS

=head2 check_byte

  my $str_or_undef = check_byte $str;

Checks that the string matches byte format.

=head2 check_date

  my $str_or_undef = check_date $str;

Validates the date part of a RFC3339 string.

=head2 check_date_time

  my $str_or_undef = check_date_time $str;

Validated against RFC3339 timestamp in UTC time. This is formatted as
"YYYY-MM-DDThh:mm:ss.fffZ". The milliseconds portion (".fff") is optional

=head2 check_duration

  my $str_or_undef = check_duration $str;

Validate a RFC3339 duration string, such as "P3Y6M4DT12H30M5S".

=head2 check_double

  my $str_or_undef = check_double $number;

Tries to check if the number is a double. Note that this check is not very
accurate.

=head2 check_email

  my $str_or_undef = check_email $str;

Validated against the RFC5322 spec.

=head2 check_float

  my $str_or_undef = check_float $number;

Tries to check if the number is a float. Note that this check is not very
accurate.

=head2 check_hostname

  my $str_or_undef = check_hostname $str;

Will be validated using L<Data::Validate::Domain/is_hostname>, if installed.

=head2 check_idn_email

  my $str_or_undef = check_idn_email $str;

Will validate an email with non-ASCII characters using L<Net::IDN::Encode> if
installed.

=head2 check_idn_hostname

  my $str_or_undef = check_idn_hostname $str;

Will validate a hostname with non-ASCII characters using L<Net::IDN::Encode> if
installed.

=head2 check_int32

  my $str_or_undef = check_int32 $number;

Tries to check if the number is a int32. Note that this check is not very
accurate.

=head2 check_int64

  my $str_or_undef = check_int64 $number;

Tries to check if the number is a int64. Note that this check is not very
accurate.

=head2 check_ipv4

  my $str_or_undef = check_ipv4 $str;

Will be validated using L<Data::Validate::IP/is_ipv4>, if installed or fall
back to a plain IPv4 IP regex.

=head2 check_ipv6

  my $str_or_undef = check_ipv6 $str;

Will be validated using L<Data::Validate::IP/is_ipv6>, if installed.

=head2 check_iri

  my $str_or_undef = check_iri $str;

Validate either an absolute IRI containing ASCII or non-ASCII characters,
against the RFC3986 spec.

=head2 check_iri_reference

  my $str_or_undef = check_iri_reference $str;

Validate either a relative or absolute IRI containing ASCII or non-ASCII
characters, against the RFC3986 spec.

=head2 check_json_pointer

  my $str_or_undef = check_json_pointer $str;

Validates a JSON pointer, such as "/foo/bar/42".

=head2 check_regex

  my $str_or_undef = check_regex $str;

Will check if the string is a regex, using C<qr{...}>.

=head2 check_relative_json_pointer

  my $str_or_undef = check_relative_json_pointer $str;

Validates a relative JSON pointer, such as "0/foo" or "3#".

=head2 check_time

  my $str_or_undef = check_time $str;

Validates the time and optionally the offset part of a RFC3339 string.

=head2 check_uri

  my $str_or_undef = check_uri $str;

Validate either a relative or absolute URI containing just ASCII characters,
against the RFC3986 spec.

Note that this might change in the future to only check absolute URI.

=head2 check_uri_reference

  my $str_or_undef = check_uri_reference $str;

Validate either a relative or absolute URI containing just ASCII characters,
against the RFC3986 spec.

=head2 check_uri_template

  my $str_or_undef = check_uri_reference $str;

Validate an absolute URI with template characters.

=head2 check_uuid

  my $str_or_undef = check_uuid $str;

Will check if C<$str> looks like an UUID. Example UUID:
"5782165B-6BB6-472F-B3DD-369D707D6C72".

=head1 SEE ALSO

L<JSON::Validator>.

=cut
