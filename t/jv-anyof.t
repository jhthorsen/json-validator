use t::Helper;
use Test::More;

my $schema = {anyOf => [{type => "string", maxLength => 5}, {type => "number", minimum => 0}]};
validate_ok $schema, 'short',    [];
validate_ok $schema, 'too long', [E('/', 'anyOf[0]: String is too long: 8/5.')];
validate_ok $schema, 12,         [];
validate_ok $schema, -1,         [E('/', 'anyOf[1]: -1 < minimum(0)')];
validate_ok $schema, {}, [E('/', 'Expected string or number, got object.')];

# anyOf with explicit integer (where _guess_data_type returns 'number')
validate_ok {anyOf => [{type => "integer"}, {minimum => 2}]}, 1, [];

# anyOf test with schema from http://json-schema.org/draft-04/schema
validate_ok(
  {
    properties => {
      whatever => {
        anyOf => [
          {'$ref' => '#/definitions/simpleTypes'},
          {
            type        => 'array',
            items       => {'$ref' => '#/definitions/simpleTypes'},
            minItems    => 1,
            uniqueItems => true,
          }
        ]
      },
    },
    definitions => {simpleTypes => {enum => [qw(array boolean integer null number object string)]}}
  },
  {whatever => ''},
  [],
);

# anyOf with nested anyOf
$schema = {
  anyOf => [
    {
      anyOf => [
        {
          type                 => 'object',
          additionalProperties => false,
          required             => ['id'],
          properties           => {id => {type => 'integer', minimum => 1}},
        },
        {
          type                 => 'object',
          additionalProperties => false,
          required             => ['id', 'name', 'role'],
          properties           => {
            id   => {type => 'integer', minimum => 1},
            name => {type => 'string'},
            role => {anyOf => [{type => 'string'}, {type => 'array'}]},
          },
        }
      ]
    },
    {type => 'integer', minimum => 1}
  ]
};
validate_ok(
  $schema,
  {id => 1, name => '', role => 123},
  [E('/role', 'anyOf[0.1]: Expected string or array, got number.')]
);
validate_ok($schema, 'string not integer', [E('/', 'Expected integer or object, got string.')]);
validate_ok($schema, {id => 1, name => 'Bob'}, [E('/role', 'anyOf[0.1]: Missing property.')]);
validate_ok($schema, {id => 1, name => 'Bob', role => 'admin'}, []);

validate_ok(
  $schema,
  {foo => 1},
  [
    E('/', 'anyOf[0.0]: Properties not allowed: foo.'),
    E('/', 'anyOf[0.1]: Properties not allowed: foo.')
  ],
);
validate_ok(
  $schema,
  {},
  [
    E('/id',   'anyOf[0.0]: Missing property.'),
    E('/id',   'anyOf[0.1]: Missing property.'),
    E('/name', 'anyOf[0.1]: Missing property.'),
    E('/role', 'anyOf[0.1]: Missing property.'),
  ]
);

done_testing;
