package JSON::Validator::Util;
use Mojo::Base -strict;

use Carp ();
use Exporter 'import';
use JSON::Validator::Error;
use List::Util;
use Mojo::Collection;
use Mojo::JSON;
use Mojo::Loader;
use Mojo::Util;
use Scalar::Util 'blessed';
use YAML::XS;

our @EXPORT_OK
  = qw(E data_checksum data_section data_type is_type schema_extract json_pointer prefix_errors schema_type);

sub E { JSON::Validator::Error->new(@_) }

my $serializer
  = eval 'use Sereal::Encoder;1' ? \&_sereal_encode : \&YAML::XS::Dump;

sub data_checksum {
  return Mojo::Util::md5_sum(
    ref $_[0] ? $serializer->($_[0]) : defined $_[0] ? qq('$_[0]') : 'undef');
}

sub data_section {
  my ($class, $file, $params) = @_;
  state $skip_re
    = qr{(^JSON::Validator|^Mojo::Base$|^Mojolicious$|\w+::_Dynamic)};

  my @classes = $class ? ([$class]) : ();
  unless (@classes) {
    my $i = 0;
    while ($class = caller($i++)) {
      push @classes, [$class] unless $class =~ $skip_re;
    }
  }

  for my $group (@classes) {
    push @$group,
      grep { !/$skip_re/ } do { no strict 'refs'; @{"$group->[0]\::ISA"} };
    for my $class (@$group) {
      next unless my $text = Mojo::Loader::data_section($class, $file);
      return Mojo::Util::encode($params->{encoding}, $text)
        if $params->{encoding};
      return $text;
    }
  }

  return undef unless $params->{confess};

  my $err = Mojo::JSON::encode_json([map { @$_ == 1 ? $_->[0] : $_ } @classes]);
  Carp::confess(qq(Could not find "$file" in __DATA__ section of $err.));
}

sub data_type {
  my $ref     = ref $_[0];
  my $blessed = blessed $_[0];
  return 'object'  if $ref eq 'HASH';
  return lc $ref   if $ref and !$blessed;
  return 'null'    if !defined $_[0];
  return 'boolean' if $blessed and ("$_[0]" eq "1" or !"$_[0]");

  if (is_type($_[0], 'NUM')) {
    return 'integer' if grep { ($_->{type} // '') eq 'integer' } @{$_[1] || []};
    return 'number';
  }

  return $blessed || 'string';
}

sub is_type {
  my $type = $_[1];

  if ($type eq 'BOOL') {
    return blessed $_[0]
      && ($_[0]->isa('JSON::PP::Boolean') || "$_[0]" eq "1" || !$_[0]);
  }

  # NUM
  if ($type eq 'NUM') {
    return
         B::svref_2object(\$_[0])->FLAGS & (B::SVp_IOK | B::SVp_NOK)
      && 0 + $_[0] eq $_[0]
      && $_[0] * 0 == 0;
  }

  # Class or data type
  return blessed $_[0] ? $_[0]->isa($type) : ref $_[0] eq $type;
}

sub schema_extract {
  my ($data, $p, $cb) = @_;
  $p = [ref $p ? @$p : length $p ? split('/', $p, -1) : $p];
  shift @$p if @$p and defined $p->[0] and !length $p->[0];
  _schema_extract($data, $p, '', $cb);
}

sub json_pointer {
  local $_ = $_[1];
  s!~!~0!g;
  s!/!~1!g;
  "$_[0]/$_";
}

sub prefix_errors {
  my ($type, @errors_with_index) = @_;
  my @errors;

  for my $e (@errors_with_index) {
    my $index = shift @$e;
    push @errors, map {
      my $msg = sprintf '/%s/%s %s', $type, $index, $_->message;
      $msg =~ s!(\d+)\s/!$1/!g;
      E $_->path, $msg;
    } @$e;
  }

  return @errors;
}

sub schema_type {
  return ''            if ref $_[0] ne 'HASH';
  return $_[0]->{type} if $_[0]->{type};
  return _guessed_right(object => $_[1]) if $_[0]->{additionalProperties};
  return _guessed_right(object => $_[1]) if $_[0]->{patternProperties};
  return _guessed_right(object => $_[1]) if $_[0]->{properties};
  return _guessed_right(object => $_[1]) if $_[0]->{propertyNames};
  return _guessed_right(object => $_[1]) if $_[0]->{required};
  return _guessed_right(object => $_[1])
    if defined $_[0]->{maxProperties}
    or defined $_[0]->{minProperties};
  return _guessed_right(array => $_[1]) if $_[0]->{additionalItems};
  return _guessed_right(array => $_[1]) if $_[0]->{items};
  return _guessed_right(array => $_[1]) if $_[0]->{uniqueItems};
  return _guessed_right(array => $_[1])
    if defined $_[0]->{maxItems}
    or defined $_[0]->{minItems};
  return _guessed_right(string => $_[1]) if $_[0]->{pattern};
  return _guessed_right(string => $_[1])
    if defined $_[0]->{maxLength}
    or defined $_[0]->{minLength};
  return _guessed_right(number => $_[1]) if $_[0]->{multipleOf};
  return _guessed_right(number => $_[1])
    if defined $_[0]->{maximum}
    or defined $_[0]->{minimum};
  return 'const' if exists $_[0]->{const};
  return '';
}

# _guessed_right($type, $data);
sub _guessed_right {
  return $_[0] if !defined $_[1];
  return $_[0] if $_[0] eq data_type $_[1], [{type => $_[0]}];
  return '';
}

sub _schema_extract {
  my ($data, $path, $pos, $cb) = @_, my $tied;

  while (@$path) {
    my $p = shift @$path;

    unless (defined $p) {
      my $i = 0;
      return Mojo::Collection->new(
        map {
          _schema_extract($_->[0], [@$path], json_pointer($pos, $_->[1]), $cb)
        } ref $data eq 'ARRAY' ? map { [$_, $i++] }
          @$data : ref $data eq 'HASH' ? map { [$data->{$_}, $_] }
          sort keys %$data : [$data, '']
      );
    }

    $p =~ s!~1!/!g;
    $p =~ s/~0/~/g;
    $pos = json_pointer $pos, $p if $cb;

    if (ref $data eq 'HASH' and exists $data->{$p}) {
      $data = $data->{$p};
    }
    elsif (ref $data eq 'ARRAY' and $p =~ /^\d+$/ and @$data > $p) {
      $data = $data->[$p];
    }
    else {
      return undef;
    }

    $data = $tied->schema if ref $data eq 'HASH' and $tied = tied %$data;
  }

  return $cb->($data, $pos) if $cb;
  return $data;
}

sub _sereal_encode {
  state $s = Sereal::Encoder->new({canonical => 1});
  return $s->encode($_[0]);
}

1;

=encoding utf8

=head1 NAME

JSON::Validator::Util - Utility functions for JSON::Validator

=head1 DESCRIPTION

L<JSON::Validator::Util> is a package containing utility functions for
L<JSON::Validator>. Each of the L</FUNCTIONS> can be imported.

=head1 FUNCTIONS

=head2 data_checksum

  $str = data_checksum $any;

Will create a checksum for any data structure stored in C<$any>.

=head2 data_section

  $str = data_section "Some::Module", "file.json";
  $str = data_section "Some::Module", "file.json", {encode => 'UTF-8'};

Same as L<Mojo::Loader/data_section>, but will also look up the file in any
inherited class.

=head2 data_type

  $str = data_type $any;
  $str = data_type $any, [@schemas];
  $str = data_type $any, [{type => "integer", ...}];

Returns the JSON type for C<$any>. C<$str> can be array, boolean, integer,
null, number object or string. Note that a list of schemas need to be provided
to differentiate between "integer" and "number".

=head2 is_type

  $bool = is_type $any, $class;
  $bool = is_type $any, $type; # $type = "ARRAY", "BOOL", "HASH", "NUM" ...

Checks if C<$any> is a, or inherits from, C<$class> or C<$type>. Two special
types can be checked:

=over 2

=item * BOOL

Checks if C<$any> is a boolean value. C<$any> is considered boolean if it is an
object inheriting from L<JSON::PP::Boolean> or is another object that
stringifies to "1" or "0".

=item * NUM

Checks if C<$any> is indeed a number.

=back

=head2 json_pointer

  $str = json_pointer $path, $append;

Will concat C<$append> on to C<$path>, but will also escape the two special
characters "~" and "/" in C<$append>.

=head2 prefix_errors

  @errors = prefix_errors $prefix, @errors;

Consider this internal for now.

=head2 schema_extract

  $data       = schema_extract $any, $json_pointer;
  $data       = schema_extract $any, "/x/cool_beans/y";
  $collection = schema_extract $any, ["x", undef, "y"];
  schema_extract $any, $json_pointer, sub { my ($data, $json_pointer) = @_ };

The basic usage is to extract data from C<$any>, using a C<$json_pointer> -
L<RFC 6901|http://tools.ietf.org/html/rfc6901>. It can however be used in a
more complex way by passing in an array-ref, instead of a plain string. The
array-ref can contain C<undef()> values, will result in extracting any element
on that point, regardsless of value. In that case a L<Mojo::Collection> will
be returned.

A callback can also be given. This callback will be called each time the
C<$json_pointer> matches some data, and will pass in the C<$json_pointer> at
that place.

In addition, if the C<$json_pointer> points to a L<JSON::Validator::Ref> at any
point, the "$ref" will be followed, while if you used L<Mojo::JSON::Pointer>,
it would return either the L<JSON::Validator::Ref> or C<undef()>.

Even though L</schema_extract> has special capabilities for handling a
JSON-Schema, it can be used for any data-structure, just like
L<Mojo::JSON::Pointer>.

=head2 schema_type

  $str = schema_type $hash_ref;
  $str = schema_type $hash_ref, $any;

Looks at C<$hash_ref> and tries to figure out what kind of type the schema
represents. C<$str> can be "array", "const", "number", "object", "string", or
fallback to empty string if the correct type could not be figured out.

C<$any> can be provided to double check the type, so if C<$hash_ref> describes
an "object", but C<$any> is an array-ref, then C<$str> will become an empty
string. Example:

  # $str = "";
  $str = schema {additionalProperties => false}, [];

  # $str = "object"
  $str = schema {additionalProperties => false};
  $str = schema {additionalProperties => false}, {};

Note that this process is relatively slow, so it will make your validation
faster if you specify "type". Both of the two below is valid, but the one with
"type" will be faster.

  {"type": "object", "properties": {}} # Faster
  {"properties": {}}                   # Slower

=head1 SEE ALSO

L<JSON::Validator>.

=cut
