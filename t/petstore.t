use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new;

$validator->schema(File::Spec->catfile(qw(t spec petstore.json)));

is_deeply(
  $validator->schema->get('/paths/~1pets/get/responses/200/schema/items'),
  {
    required   => ["id", "name"],
    properties => {
      id   => {type => "integer", format => "int64"},
      name => {type => "string"},
      tag  => {type => "string"}
    }
  },
  'expanded /paths/~1pets/get/responses/200/schema/items'
);

ok !find_key($validator->schema->data, '$ref'), 'no $ref in schema';

done_testing;

sub find_key {
  my ($data, $needle) = @_;

  for my $k (keys %$data) {
    return 1 if $k eq $needle;
    return 1 if ref $data->{$k} eq 'HASH' and find_key($data->{$k}, $needle);
  }

  return 0;
}
