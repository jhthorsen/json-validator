package JSON::Validator::Util;
use Mojo::Base -strict;

use Exporter 'import';
use JSON::Validator::Error;
use Scalar::Util 'blessed';

our @EXPORT_OK = (
  qw(E add_path_to_error_messages guess_data_type guess_schema_type),
  qw(is_boolean is_number json_path uniq),
);

sub E { JSON::Validator::Error->new(@_) }

sub add_path_to_error_messages {
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

sub guess_data_type {
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

sub guess_schema_type {
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
  return undef;
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

sub json_path {
  local $_ = $_[1];
  s!~!~0!g;
  s!/!~1!g;
  "$_[0]/$_";
}

sub uniq {
  my %uniq;
  grep { !$uniq{$_}++ } @_;
}

# _guessed_right($type, $data);
sub _guessed_right {
  return $_[0] if !defined $_[1];
  return $_[0] if $_[0] eq guess_data_type($_[1], [{type => $_[0]}]);
  return undef;
}

1;
