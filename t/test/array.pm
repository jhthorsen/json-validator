package t::test::array;
use t::Helper;

sub additional_items {
  my $schema = {
    type            => 'array',
    additionalItems => false,
    items           => [
      {type => 'number'},
      {type => 'string'},
      {type => 'string', enum => ['Street', 'Avenue', 'Boulevard']},
      {type => 'string', enum => ['NW', 'NE', 'SW', 'SE']}
    ]
  };

  validate_ok [1600, 'Pennsylvania', 'Avenue', 'NW', 'Washington'], $schema, E('/', 'Invalid number of items: 5/4.');
}

sub basic {
  my $schema = {type => 'array'};
  schema_validate_ok [], $schema;
  schema_validate_ok {}, $schema, E('/', 'Expected array - got object.');
}

sub contains {
  my $schema = {type => 'array', contains => {type => 'string', enum => ['NW']}};
  schema_validate_ok [1600, 'NW'], $schema;

  $schema->{contains}{enum} = ['Nope'];
  schema_validate_ok [1600, 'NW'], $schema, E('/0', 'Expected string - got number.'),
    E('/1', 'Not in enum list: Nope.');
}

sub items {
  my $schema = {type => 'array', items => {type => 'number'}};
  validate_ok [1], $schema;
  validate_ok [1, 'foo'], $schema, E('/1', 'Expected number - got string.');

  $schema->{items} = {};
  validate_ok [1, 'foo', 1.2], $schema;

  $schema->{items} = true;
  validate_ok [1, 'foo', 1.2], $schema;
}

sub min_max {
  my $schema = {type => 'array', minItems => 2, maxItems => 2};

  schema_validate_ok [1], $schema, E('/', 'Not enough items: 1/2.');
  schema_validate_ok [1, 2], $schema;
  schema_validate_ok [1, 2, 3], $schema, E('/', 'Too many items: 3/2.');
}

sub min_max_contains {
  my $schema = {type => 'array', contains => {type => 'string'}, maxContains => 3, minContains => 2};
  schema_validate_ok [qw(A)],       $schema, E('/', 'Contains not enough items: 1/2.');
  schema_validate_ok [qw(A B C D)], $schema, E('/', 'Contains too many items: 4/3.');
  schema_validate_ok [qw(A B)],     $schema;
  schema_validate_ok [qw(A B C)],   $schema;
}

sub unevaluated_items {
  local $TODO = 'https://json-schema.org/draft/2019-09/json-schema-core.html#unevaluatedItems';
  my $schema = {unevaluatedItems => {}};
  validate_ok [1600, 'Pennsylvania', 'Avenue', 'NW', 'Washington'], $schema, E('/', 'Invalid number of items: 5/4.');
}

sub unique {
  my $schema = {type => 'array', uniqueItems => 1, items => {type => 'integer'}};
  validate_ok [123, 124], $schema;
  validate_ok [1, 2, 1], $schema, E('/', 'Unique items required.');
}

1;
