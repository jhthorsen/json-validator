use lib '.';
use t::Helper;

my $schema
  = {anyOf =>
    [{type => "string", maxLength => 5}, {type => "number", minimum => 0}]
  };

validate_ok 'short', $schema;
validate_ok 'too long', $schema, E('/', '/anyOf/0 String is too long: 8/5.'),
  E('/', '/anyOf/1 Expected number - got string.');

validate_ok 12, $schema;
validate_ok int(-1), $schema, E('/', '/anyOf/0 Expected string - got number.'),
  E('/', '/anyOf/1 -1 < minimum(0)');

validate_ok {}, $schema, E('/', '/anyOf Expected string/number - got object.');

# anyOf with explicit integer (where _guess_data_type returns 'number')
my $schemaB = {anyOf => [{type => 'integer'}, {minimum => 2}]};
validate_ok 1, $schemaB;

validate_ok(
  {type => 'string'},
  {
    properties => {
      type => {
        anyOf => [
          {'$ref' => '#/definitions/simpleTypes'},
          {
            type        => 'array',
            items       => {'$ref' => '#/definitions/simpleTypes'},
            minItems    => 1,
            uniqueItems => Mojo::JSON::true,
          }
        ]
      },
    },
    definitions => {
      simpleTypes =>
        {enum => [qw(array boolean integer null number object string)]}
    }
  }
);

validate_ok(
  {age => 6},
  {
    '$schema'   => 'http://json-schema.org/draft-04/schema#',
    type        => 'object',
    title       => 'test',
    description => 'test',
    properties  => {
      age => {type => 'number', anyOf => [{multipleOf => 5}, {multipleOf => 3}]}
    }
  }
);

validate_ok(
  {c => 'c present, a/b is missing'},
  {
    type       => 'object',
    properties => {a => {type => 'number'}, b => {type => 'string'}},
    anyOf      => [{required => ['a']}, {required => ['b']}],
  },
  E('/a', '/anyOf/0 Missing property.'),
  E('/b', '/anyOf/1 Missing property.'),
);

validate_ok 'hello', {type => ['integer', 'string'], enum => [123, 'HELLO']},
  E('/', 'Not in enum list: 123, HELLO.');

validate_ok 'hello', {anyOf => [false, {type => ['integer', 'boolean']}]},
  E('/', '/anyOf/0 Should not match.'),
  E('/', '/anyOf/1 Expected integer/boolean - got string.');

validate_ok 'hello', {type => ['integer', 'boolean']},
  E('/', 'Expected integer/boolean - got string.');

validate_ok 'hello', {anyOf => [{type => ['integer', 'boolean']}]},
  E('/', '/anyOf/0 Expected integer/boolean - got string.');

validate_ok 'hello',
  {
  anyOf => [
    {anyOf => [{type => 'boolean'}, {type => 'string', maxLength => 2}]},
    {type  => 'integer'},
  ],
  },
  E('/', '/anyOf/0/anyOf/0 Expected boolean - got string.'),
  E('/', '/anyOf/0/anyOf/1 String is too long: 5/2.'),
  E('/', '/anyOf/1 Expected integer - got string.');

done_testing;
