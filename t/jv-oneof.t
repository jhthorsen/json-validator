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
validate_ok 13, $schema, E('/', '/oneOf/1 Not multiple of 3.');

# Alternative oneOf
# http://json-schema.org/latest/json-schema-validation.html#anchor79
$schema = {
  type       => 'object',
  properties => {x => {type => ['string', 'null'], format => 'date-time'}}
};
validate_ok {x => 'foo'}, $schema,
  E('/x', '/anyOf/0 Does not match date-time format.');
validate_ok {x => '2015-04-21T20:30:43.000Z'}, $schema;
validate_ok {x => undef}, $schema;

done_testing;
