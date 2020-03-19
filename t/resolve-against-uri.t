use Mojo::Base -base;
use lib '.';
use t::Helper;

my $schema1 = {
  '$schema'  => 'http://json-schema.org/draft-07/schema#',
  '$id'      => 'http://127.0.0.1:50754/json_schema/refs/self with spaces/1',
  type       => 'object',
  properties => {
    a           => {type  => 'string', minLength => 4},
    b           => {allOf => [{minLength => 3}, {'$ref' => '#/properties/a'},]},
    'space age' => {type  => 'number'},
  },
};

my $schema2 = {
  '$schema'  => 'http://json-schema.org/draft-07/schema#',
  '$id'      => 'http://127.0.0.1:50754/json_schema/refs/other/1',
  type       => 'object',
  properties => {
    a => {
      allOf => [
        {minLength => 3},
        {'$ref'    => '/json_schema/refs/self with spaces/1#/properties/a'},
        {
          '$ref' => '/json_schema/refs/self with spaces/1#/properties/space age'
        },
        {'$ref' => 'new_base#'},    # this resolves to our document
      ]
    },

    # to_abs = http://127.0.0.1:50754/json_schema/refs/other/new_base
    new_base => {'$id' => 'new_base', type => 'boolean',},
  },
};

jv()->version(7);

validate_ok {a => 'hi'}, $schema1, E('/a', 'String is too short: 2/4.');

validate_ok {a => 'hi'}, $schema2,
  E('/a', '/allOf/0 String is too short: 2/3.'),
  E('/a', '/allOf/1 String is too short: 2/4.'),
  E('/a', '/allOf/2 Expected number - got string.'),
  E('/a', '/allOf/3 Expected boolean - got string.');

done_testing;
