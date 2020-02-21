use lib '.';
use t::Helper;

my $schema
  = {oneOf =>
    [{type => 'string', maxLength => 5}, {type => 'number', minimum => 0}]
  };

validate_ok 'short', $schema;
validate_ok 12,      $schema;

$schema
  = {oneOf =>
    [{type => 'number', multipleOf => 5}, {type => 'number', multipleOf => 3}]
  };
validate_ok 10, $schema;
validate_ok 9,  $schema;
validate_ok 15, $schema, E('/', 'All of the oneOf rules match.');
validate_ok 13, $schema, E('/', '/oneOf/0 Not multiple of 5.'),
  E('/', '/oneOf/1 Not multiple of 3.');

$schema = {oneOf => [{type => 'object'}, {type => 'string', multipleOf => 3}]};
validate_ok 13, $schema, E('/', '/oneOf Expected object/string - got number.');

$schema = {oneOf => [{type => 'object'}, {type => 'number', multipleOf => 3}]};
validate_ok 13, $schema, E('/', '/oneOf/0 Expected object - got number.'),
  E('/', '/oneOf/1 Not multiple of 3.');

# Alternative oneOf
# https://json-schema.org/draft-07/json-schema-validation.html#rfc.section.7
$schema = {
  type       => 'object',
  properties => {x => {type => ['string', 'null'], format => 'date-time'}}
};
validate_ok {x => 'foo'}, $schema, E('/x', 'Does not match date-time format.'),
  E('/x', 'Not null.');

validate_ok {x => '2015-04-21T20:30:43.000Z'}, $schema;
validate_ok {x => undef},                      $schema;

validate_ok 1, {oneOf => [{minimum => 1}, {minimum => 2}, {maximum => 3}]},
  E('/', 'oneOf rules 0, 2 match.');

validate_ok 'hello', {oneOf => [true, false]};

validate_ok 'hello', {oneOf => [true, true]},
  E('/', 'All of the oneOf rules match.');

validate_ok 'hello', {oneOf => [false, false]},
  E('/', '/oneOf/0 Should not match.'), E('/', '/oneOf/1 Should not match.');

validate_ok 'hello', {oneOf => [true, {type => ['string', 'boolean']}]},
  E('/', 'All of the oneOf rules match.');

validate_ok 'hello', {type => ['integer', 'boolean']},
  E('/', 'Expected integer/boolean - got string.');

validate_ok 'hello',
  {oneOf => [false, {type => ['integer', 'string'], enum => [123, 'HELLO']}]},
  E('/', '/oneOf/0 Should not match.'),
  E('/', '/oneOf/1 Not in enum list: 123, HELLO.');

validate_ok 'hello', {oneOf => [false, {type => ['integer', 'boolean']}]},
  E('/', '/oneOf/0 Should not match.'),
  E('/', '/oneOf/1 Expected integer/boolean - got string.');

validate_ok 'hello', {oneOf => [false, {type => 'integer'}]},
  E('/', '/oneOf/0 Should not match.'),
  E('/', '/oneOf/1 Expected integer - got string.');

validate_ok 'hello', {oneOf => [{type => ['integer', 'boolean']}]},
  E('/', '/oneOf/0 Expected integer/boolean - got string.');

validate_ok 'hello',
  {
  oneOf => [
    {oneOf => [{type => 'boolean'}, {type => 'string', maxLength => 2}]},
    {type  => 'integer'},
  ],
  },
  E('/', '/oneOf/0/oneOf/0 Expected boolean - got string.'),
  E('/', '/oneOf/0/oneOf/1 String is too long: 5/2.'),
  E('/', '/oneOf/1 Expected integer - got string.');

done_testing;
