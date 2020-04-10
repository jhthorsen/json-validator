package JSON::Validator::Schema::Draft4;
use Mojo::Base 'JSON::Validator::Schema';

use JSON::Validator::Util 'is_type';

has id => sub {
  my $data = shift->data;
  return is_type($data, 'HASH') ? $data->{id} || '' : '';
};

has specification => 'http://json-schema.org/draft-04/schema#';

sub _build_formats {
  return {
    'date-time' => JSON::Validator::Formats->can('check_date_time'),
    'email'     => JSON::Validator::Formats->can('check_email'),
    'hostname'  => JSON::Validator::Formats->can('check_hostname'),
    'ipv4'      => JSON::Validator::Formats->can('check_ipv4'),
    'ipv6'      => JSON::Validator::Formats->can('check_ipv6'),
    'regex'     => JSON::Validator::Formats->can('check_regex'),
    'uri'       => JSON::Validator::Formats->can('check_uri'),
  };
}

sub _id_key {'id'}

1;

=encoding utf8

=head1 NAME

JSON::Validator::Schema::Draft4 - JSON-Schema Draft 4

=head1 SYNOPSIS

See L<JSON::Validator::Schema/SYNOPSIS>.

=head1 DESCRIPTION

This class represents
L<https://json-schema.org/specification-links.html#draft-4>.

=head1 ATTRIBUTES

=head2 specification

  my $str    = $schema->specification;
  my $schema = $schema->specification($str);

Defaults to "L<http://json-schema.org/draft-04/schema#>".

=head1 SEE ALSO

L<JSON::Validator::Schema>.

=cut
