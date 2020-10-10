package t::test::object;
use t::Helper;

sub additional_properties {
  my $schema = {properties => {number => {type => 'number'}}, additionalProperties => false};

  schema_validate_ok {direction => 'NW', foo => 'nope', number => 1600}, $schema,
    E('/', 'Properties not allowed: direction, foo.');

  $schema->{additionalProperties} = {type => 'string'};
  schema_validate_ok {number => 1600, foo => 'nope'}, $schema;
}

sub basic {
  my $schema = {type => 'object'};
  schema_validate_ok {mynumber => 1}, $schema;
  schema_validate_ok [1], $schema, E('/', 'Expected object - got array.');
}

sub dependencies {
  my $schema = {
    dependencies => {credit_card => ['billing_address']},
    properties =>
      {name => {type => 'string'}, credit_card => {type => 'number'}, billing_address => {type => 'string'}},
  };

  schema_validate_ok {name => 'John Doe'}, $schema;
  schema_validate_ok {name => 'John Doe', billing_address => '123 Main St'},    $schema;
  schema_validate_ok {name => 'John Doe', credit_card     => 5555555555555555}, $schema,
    E('/billing_address', 'Missing property. Dependee: credit_card.');
}

sub dependent_required {
  my $schema = {
    dependentRequired => {credit_card => ['billing_address']},
    properties =>
      {name => {type => 'string'}, credit_card => {type => 'number'}, billing_address => {type => 'string'}},
  };

  schema_validate_ok {name => 'John Doe', credit_card => 5555555555555555}, $schema,
    E('/billing_address', 'Missing property. Dependee: credit_card.');
}

sub dependent_schemas {
  my $schema = {
    dependentSchemas => {credit_card => ['billing_address']},
    properties =>
      {name => {type => 'string'}, credit_card => {type => 'number'}, billing_address => {type => 'string'}},
  };

  schema_validate_ok {name => 'John Doe', credit_card => 5555555555555555}, $schema,
    E('/billing_address', 'Missing property. Dependee: credit_card.');
}

sub min_max {
  my $schema = {minProperties => 2, maxProperties => 3};
  schema_validate_ok {}, {minProperties => 1}, E('/', 'Not enough properties: 0/1.');
  schema_validate_ok {a => 1}, $schema, E('/', 'Not enough properties: 1/2.');
  schema_validate_ok {a => 1, b => 2}, $schema;
  schema_validate_ok {a => 1, b => 2, c => 3}, $schema;
  schema_validate_ok {a => 1, b => 2, c => 3, d => 4}, $schema, E('/', 'Too many properties: 4/3.');
}

sub names {
  my $schema = {propertyNames => {minLength => 3, maxLength => 5}};
  schema_validate_ok {name => 'John', surname => 'Doe'}, $schema,
    E('/', '/propertyName/surname String is too long: 7/5.');

  $schema->{propertyNames}{maxLength} = 7;
  schema_validate_ok {name => 'John', surname => 'Doe'}, $schema;

  $schema = {
    type => 'object',
    propertyNames =>
      {anyOf => [{type => 'string', enum => ['foo', 'bar', 'baz']}, {type => 'string', enum => ['hello']}]},
  };

  schema_validate_ok {FOO => 1}, $schema, E('/', '/propertyName/FOO /anyOf/0 Not in enum list: foo, bar, baz.'),
    E('/', '/propertyName/FOO /anyOf/1 Not in enum list: hello.');

  schema_validate_ok {foo => 1}, $schema;
}

sub pattern_properties {
  my $schema = {patternProperties => {'^S_' => {type => 'string'}, '^I_' => {type => 'integer'}}};

  schema_validate_ok {'S_25' => 'This is a string', 'I_0' => 42}, $schema;
  schema_validate_ok {'S_0' => 42}, $schema, E('/S_0', 'Expected string - got number.');
}

sub properties {
  my $schema = {
    properties => {
      number      => {type => 'number'},
      street_name => {type => 'string'},
      street_type => {type => 'string', enum => ['Street', 'Avenue', 'Boulevard']}
    }
  };

  schema_validate_ok {number => 1600, street_name => 'Pennsylvania', street_type => 'Avenue'}, $schema;
  schema_validate_ok {number => '1600'}, $schema, E('/number', 'Expected number - got string.');
  schema_validate_ok {number => 1600, street_name => 'Pennsylvania', street_type => 'Avenue', direction => 'NW'},
    $schema;

  $schema->{required} = ['number', 'street_name'];
  validate_ok {number => 1600, street_type => 'Avenue'}, $schema, E('/street_name', 'Missing property.');
}

sub unevaluated_properties {
  local $TODO = 'https://json-schema.org/draft/2019-09/json-schema-core.html#rfc.section.9.3.2.4';
  my $schema = {properties => {number => {type => 'number'}}, unevaluatedProperties => false};

  schema_validate_ok {direction => 'NW', foo => 'nope', number => 1600}, $schema,
    E('/', 'Properties not allowed: direction, foo.');
}

1;
