use lib '.';
use t::Helper;

my $schema
  = {anyOf =>
    [{type => "string", maxLength => 5}, {type => "number", minimum => 0}]
  };

validate_ok 'short',    $schema;
validate_ok 'too long', $schema, E('/', '/anyOf/0 String is too long: 8/5.');
validate_ok 12,         $schema;
validate_ok int(-1), $schema, E('/', '/anyOf/1 -1 < minimum(0)');
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

done_testing;
