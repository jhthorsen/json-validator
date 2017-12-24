use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new;
my $bundled;

# Run multiple times to make sure _reset() works
for my $n (1 .. 3) {
  note "[$n] replace=1";
  $bundled = $validator->bundle(
    {
      replace => 1,
      schema =>
        {name => {'$ref' => '#/definitions/name'}, definitions => {name => {type => 'string'}}},
    }
  );

  is $bundled->{name}{type}, 'string', "[$n] replace=1";

  note "[$n] replace=0";
  $bundled = $validator->schema(
    {
      name        => {'$ref' => '#/definitions/name'},
      age         => {'$ref' => 'b.json#/definitions/age'},
      definitions => {name   => {type => 'string'}},
      B           => {id     => 'b.json', definitions => {age => {type => 'integer'}}},
    }
  )->bundle;
  is $bundled->{definitions}{name}{type}, 'string', "[$n] name still in definitions";
  is $bundled->{definitions}{'_b_json-_definitions_age'}{type}, 'integer',
    "[$n] added to definitions";
  isnt $bundled->{age}, $validator->schema->get('/age'),  "[$n] new age ref";
  is $bundled->{name},  $validator->schema->get('/name'), "[$n] same name ref";
  is $bundled->{age}{'$ref'}, '#/definitions/_b_json-_definitions_age',
    "[$n] age \$ref point to /definitions/_b_json-_definitions_age";
  is $bundled->{name}{'$ref'}, '#/definitions/name', "[$n] name \$ref point to /definitions/name";
}

is $validator->get([qw(name type)]), 'string', 'get /name/$ref';
is $validator->get('/name/type'), 'string', 'get /name/type';
is $validator->get('/name/$ref'), undef,    'get /name/$ref';
is $validator->schema->get('/name/type'), 'string',             'schema get /name/type';
is $validator->schema->get('/name/$ref'), '#/definitions/name', 'schema get /name/$ref';

done_testing;
