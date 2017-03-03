use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new;

# from http://json-schema.org/latest/json-schema-core.html#anchor30
$validator->schema(
  {
    id          => 'http://json-schema.example.com/myschema#',
    definitions => {
      schema1 => {id   => 'schema1', type  => 'integer'},
      schema2 => {type => 'array',   items => {'$ref' => 'schema1'}}
    }
  }
);

is_deeply(
  $validator->schema->get('/definitions/schema2'),
  {type => 'array', items => {id => 'schema1', type => 'integer'}},
  'expanded schema2'
);

ok !find_key($validator->schema->data, '$ref'), 'no $ref';

done_testing;

sub find_key {
  my ($data, $needle) = @_;

  for my $k (keys %$data) {
    return 1 if $k eq $needle;
    return 1 if ref $data->{$k} eq 'HASH' and find_key($data->{$k}, $needle);
  }

  return 0;
}
