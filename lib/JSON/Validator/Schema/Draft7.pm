package JSON::Validator::Schema::Draft7;
use Mojo::Base 'JSON::Validator::Schema::Draft6';

use JSON::Validator::Util 'E';

has specification => 'http://json-schema.org/draft-07/schema#';

sub _build_formats {
  return {
    'date'          => JSON::Validator::Formats->can('check_date'),
    'date-time'     => JSON::Validator::Formats->can('check_date_time'),
    'duration'      => JSON::Validator::Formats->can('check_duration'),
    'email'         => JSON::Validator::Formats->can('check_email'),
    'hostname'      => JSON::Validator::Formats->can('check_hostname'),
    'idn-email'     => JSON::Validator::Formats->can('check_idn_email'),
    'idn-hostname'  => JSON::Validator::Formats->can('check_idn_hostname'),
    'ipv4'          => JSON::Validator::Formats->can('check_ipv4'),
    'ipv6'          => JSON::Validator::Formats->can('check_ipv6'),
    'iri'           => JSON::Validator::Formats->can('check_iri'),
    'iri-reference' => JSON::Validator::Formats->can('check_iri_reference'),
    'json-pointer'  => JSON::Validator::Formats->can('check_json_pointer'),
    'regex'         => JSON::Validator::Formats->can('check_regex'),
    'relative-json-pointer' =>
      JSON::Validator::Formats->can('check_relative_json_pointer'),
    'time'          => JSON::Validator::Formats->can('check_time'),
    'uri'           => JSON::Validator::Formats->can('check_uri'),
    'uri-reference' => JSON::Validator::Formats->can('check_uri_reference'),
    'uri-template'  => JSON::Validator::Formats->can('check_uri_template'),
    'uuid'          => JSON::Validator::Formats->can('check_uuid'),
  };
}

sub _definitions_path_for_ref { ['$defs'] }

sub _validate_type_array_contains {
  my ($self, $data, $path, $schema) = @_;
  return unless $schema->{contains};

  my ($n_items, $n_ok, @e, @errors) = (int @$data, 0);
  for my $i (0 .. @$data - 1) {
    my @tmp = $self->_validate($data->[$i], "$path/$i", $schema->{contains});
    $n_ok++ unless @tmp;
    push @e, \@tmp if @tmp;
  }

  push @errors, map {@$_} @e if @e >= $n_items;
  push @errors, E $path, [array => 'contains'] if not $n_items;

  push @errors, E $path,
    [array => maxContains => $n_items, $schema->{maxContains}]
    if defined $schema->{maxContains} and $n_ok > $schema->{maxContains};
  push @errors, E $path,
    [array => minContains => $n_items, $schema->{minContains}]
    if defined $schema->{minContains} and $n_ok < $schema->{minContains};

  return @errors;
}

1;

=encoding utf8

=head1 NAME

JSON::Validator::Schema::Draft7 - JSON-Schema Draft 7

=head1 SYNOPSIS

See L<JSON::Validator::Schema/SYNOPSIS>.

=head1 DESCRIPTION

This class represents
L<https://json-schema.org/specification-links.html#draft-7>.

=head1 ATTRIBUTES

=head2 specification

  my $str = $schema->specification;

Defaults to "L<http://json-schema.org/draft-07/schema#>".

=head1 SEE ALSO

L<JSON::Validator::Schema>.

=cut
