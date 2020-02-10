package JSON::Validator::Util;
use Mojo::Base -strict;

use Data::Dumper ();
use Exporter 'import';
use JSON::Validator::Error;
use Mojo::Loader;
use Mojo::Util;
use Scalar::Util 'blessed';

our @EXPORT_OK = (
  qw(E data_checksum data_section data_type schema_type prefix_errors),
  qw(is_boolean is_number is_type json_path uniq),
);

sub E { JSON::Validator::Error->new(@_) }

sub data_checksum {
  Mojo::Util::md5_sum(Data::Dumper->new([@_])->Sortkeys(1)->Useqq(1)->Dump);
}

sub data_section {
  my ($class, $file, $params) = @_;
  state $class_skip_re
    = qr{(^JSON::Validator$|^Mojo::Base$|^Mojolicious$|\w+::_Dynamic)};

  unless ($class) {
    my $i = 1;
    while ($class = caller($i++)) {
      last unless $class =~ $class_skip_re;
    }
  }

  my @classes = do { no strict 'refs'; ($class, @{"$class\::ISA"}) };
  my $text;
  for my $class (@classes) {
    next if $class =~ $class_skip_re;
    last if $text = Mojo::Loader::data_section($class, $file);
  }

  $text = Mojo::Util::encode($params->{encoding}, $text)
    if $text and $params->{encoding};
  $text;
}

sub data_type {
  my $ref     = ref $_[0];
  my $blessed = blessed $_[0];
  return 'object'  if $ref eq 'HASH';
  return lc $ref   if $ref and !$blessed;
  return 'null'    if !defined $_[0];
  return 'boolean' if $blessed and ("$_[0]" eq "1" or !"$_[0]");

  if (is_number($_[0])) {
    return 'integer' if grep { ($_->{type} // '') eq 'integer' } @{$_[1] || []};
    return 'number';
  }

  return $blessed || 'string';
}

sub is_boolean {
  return blessed $_[0]
    && ($_[0]->isa('JSON::PP::Boolean') || "$_[0]" eq "1" || !$_[0]);
}

sub is_number {
  B::svref_2object(\$_[0])->FLAGS & (B::SVp_IOK | B::SVp_NOK)
    && 0 + $_[0] eq $_[0]
    && $_[0] * 0 == 0;
}

sub is_type {
  return blessed $_[0] ? $_[0]->isa($_[1]) : ref $_[0] eq $_[1];
}

sub json_path {
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
  return $_[0]->{type} if $_[0]->{type};
  return _guessed_right(object => $_[1]) if $_[0]->{additionalProperties};
  return _guessed_right(object => $_[1]) if $_[0]->{patternProperties};
  return _guessed_right(object => $_[1]) if $_[0]->{properties};
  return _guessed_right(object => $_[1]) if $_[0]->{propertyNames};
  return _guessed_right(object => $_[1]) if $_[0]->{required};
  return _guessed_right(object => $_[1]) if $_[0]->{if};
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

sub uniq {
  my %uniq;
  grep { !$uniq{$_}++ } @_;
}

# _guessed_right($type, $data);
sub _guessed_right {
  return $_[0] if !defined $_[1];
  return $_[0] if $_[0] eq data_type $_[1], [{type => $_[0]}];
  return '';
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

=head2 is_boolean

  $bool = is_boolean $any;

Checks if C<$any> is a boolean value. C<$any> is considered boolean if it is an
object inheriting from L<JSON::PP::Boolean> or is another object that
stringifies to "1" or "0".

=head2 is_number

  $bool = is_number $any;

Checks if C<$any> is indeed a number.

=head2 is_type

  $bool = is_type $any, $class;
  $bool = is_type $any, $type; # $type = "ARRAY", "HASH", ...

Checks if C<$any> is a, or inherit from C<$class> or C<$type>.

=head2 json_path

  $str = json_path $path, $append;

Will concat C<$append> on to C<$path>, but will also escape the two special
characters "~" and "/" in C<$append>.

=head2 prefix_errors

  @errors = prefix_errors $prefix, @errors;

Consider this internal for now.

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

=head2 uniq

  @items = uniq @items;

See L<List::Util/uniq>.

=head1 SEE ALSO

L<JSON::Validator>.

=cut
