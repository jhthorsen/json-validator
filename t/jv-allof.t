use lib '.';
use t::Helper;

my $schema
  = {allOf =>
    [{type => 'string', maxLength => 5}, {type => 'string', minLength => 3}]
  };

validate_ok 'short', $schema;
validate_ok 12, $schema, E('/', '/allOf Expected string - got number.');

$schema
  = {allOf =>
    [{type => 'string', maxLength => 7}, {type => 'string', maxLength => 5}]
  };
validate_ok 'superlong', $schema, E('/', '/allOf/0 String is too long: 9/7.'),
  E('/', '/allOf/1 String is too long: 9/5.');
validate_ok 'toolong', $schema, E('/', '/allOf/1 String is too long: 7/5.');


$schema = {
  allOf =>
    [{type => 'string', maxLength => 5}, {type => 'string', minLength => 3}],
  anyOf => [{pattern => '^[0-9]+$'}, {pattern => '^[a-z]+$'}],
  oneOf => [{pattern => '^[0-9]+$'}, {pattern => '^[a-z]+$', maxLength => 4}],
};

validate_ok '123',   $schema;
validate_ok 'aaaa',  $schema;
validate_ok 'aaaaa', $schema,
  E('/', '/oneOf/0 String does not match ^[0-9]+$.'),
  E('/', '/oneOf/1 String is too long: 5/4.');

validate_ok 'he110th3re', $schema,
  E('/', '/allOf/0 String is too long: 10/5.'),
  E('/', '/anyOf/0 String does not match ^[0-9]+$.'),
  E('/', '/anyOf/1 String does not match ^[a-z]+$.'),
  E('/', '/oneOf/0 String does not match ^[0-9]+$.'),
  E('/', '/oneOf/1 String is too long: 10/4.'),
  E('/', '/oneOf/1 String does not match ^[a-z]+$.');

validate_ok 'hello', {type => ['integer', 'boolean']},
  E('/', 'Expected integer/boolean - got string.');

validate_ok 'hello', {allOf => [true, {type => ['integer', 'boolean']}]},
  E('/', '/allOf/1 Expected integer/boolean - got string.');

done_testing;
