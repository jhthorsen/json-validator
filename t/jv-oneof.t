use t::Helper;
use Test::More;

my $schema = {oneOf => [{type => 'string', maxLength => 5}, {type => 'number', minimum => 0}]};
validate_ok $schema, 'short', [];
validate_ok $schema, 12,      [];

$schema = {oneOf => [{type => 'number', multipleOf => 5}, {type => 'number', multipleOf => 3}]};
validate_ok $schema, 10, [];
validate_ok $schema, 9,  [];
validate_ok $schema, 15, [E('/', 'All of the oneOf rules match.')];
validate_ok $schema, 13,
  [E('/', 'oneOf[0]: Not multiple of 5.'), E('/', 'oneOf[1]: Not multiple of 3.')];

$schema = {oneOf => [{type => 'object'}, {type => 'string'}]};
validate_ok $schema, 13, [E('/', 'Expected object or string, got number.')];

$schema = {oneOf => [{type => 'object'}, {type => 'number', multipleOf => 3}]};
validate_ok $schema, 13, [E('/', 'oneOf[1]: Not multiple of 3.')];

# Alternative oneOf
# http://json-schema.org/latest/json-schema-validation.html#anchor79
$schema
  = {type => 'object', properties => {x => {type => ['string', 'null'], format => 'date-time'}}};
validate_ok $schema, {x => 'foo'}, [E('/x', 'anyOf[0]: Does not match date-time format.')];
validate_ok $schema, {x => '2015-04-21T20:30:43.000Z'}, [];
validate_ok $schema, {x => undef}, [];

done_testing;
