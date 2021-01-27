use lib '.';
use t::Helper;

my $schema;

subtest 'basic' => sub {
  $schema = {type => 'object'};
  validate_ok {mynumber => 1}, $schema;
  validate_ok [1], $schema, E('/', 'Expected object - got array.');
};

subtest 'patternProperties' => sub {
  $schema->{properties} = {
    number      => {type => 'number'},
    street_name => {type => 'string'},
    street_type => {type => 'string', enum => ['Street', 'Avenue', 'Boulevard']}
  };
  local $schema->{patternProperties} = {'^S_' => {type => 'string'}, '^I_' => {type => 'integer'}};

  validate_ok {number => 1600,   street_name => 'Pennsylvania', street_type => 'Avenue'}, $schema;
  validate_ok {number => '1600', street_name => 'Pennsylvania', street_type => 'Avenue'}, $schema,
    E('/number', 'Expected number - got string.');
  validate_ok {number => 1600, street_name => 'Pennsylvania'}, $schema;
  validate_ok {number => 1600, street_name => 'Pennsylvania', street_type => 'Avenue', direction => 'NW'}, $schema;
  validate_ok {'S_25' => 'This is a string', 'I_0' => 42}, $schema;
  validate_ok {'S_0' => 42}, $schema, E('/S_0', 'Expected string - got number.');
};

subtest 'additionalProperties' => sub {
  local $schema->{additionalProperties} = 0;
  validate_ok {number => 1600, street_name => 'Pennsylvania', street_type => 'Avenue', direction => 'NW',
    foo => 'nope'}, $schema, E('/', 'Properties not allowed: direction, foo.');

  $schema->{additionalProperties} = {type => 'string'};
  validate_ok {number => 1600, street_name => 'Pennsylvania', street_type => 'Avenue', direction => 'NW'}, $schema;
};

subtest 'required' => sub {
  local $schema->{required} = ['number', 'street_name'];
  validate_ok {number => 1600, street_type => 'Avenue'}, $schema, E('/street_name', 'Missing property.');
};

subtest 'minProperties maxProperties' => sub {
  $schema = {type => 'object', minProperties => 1};
  validate_ok {}, $schema, E('/', 'Not enough properties: 0/1.');
  $schema = {type => 'object', minProperties => 2, maxProperties => 3};
  validate_ok {a => 1}, $schema, E('/', 'Not enough properties: 1/2.');
  validate_ok {a => 1, b => 2}, $schema;
  validate_ok {a => 1, b => 2, c => 3, d => 4}, $schema, E('/', 'Too many properties: 4/3.');
};

subtest 'dependencies' => sub {
  $schema = {
    type       => 'object',
    properties =>
      {name => {type => 'string'}, credit_card => {type => 'number'}, billing_address => {type => 'string'}},
    required     => ['name'],
    dependencies => {credit_card => ['billing_address']}
  };

  validate_ok {name => 'John Doe'}, $schema;
  validate_ok {name => 'John Doe', billing_address => '123 Main St'},    $schema;
  validate_ok {name => 'John Doe', credit_card     => 5555555555555555}, $schema,
    E('/billing_address', 'Missing property. Dependee: credit_card.');

  $schema = {
    type         => 'object',
    properties   => {name => {type => 'string'}, credit_card => {type => 'number'}},
    required     => ['name'],
    dependencies =>
      {credit_card => {properties => {billing_address => {type => 'string'}}, required => ['billing_address']}},
  };

  validate_ok {name => 'John Doe'}, $schema;
  validate_ok {name => 'John Doe', billing_address => '123 Main St'},    $schema;
  validate_ok {name => 'John Doe', credit_card     => 5555555555555555}, $schema,
    E('/billing_address', 'Missing property.');

  $schema = {dependencies => {bar => ['foo']}};
  validate_ok {bar => 2}, $schema, E('/foo', 'Missing property. Dependee: bar.');

  validate_ok {FOO => 1},
    {
    type          => 'object',
    propertyNames =>
      {anyOf => [{type => 'string', enum => ['foo', 'bar', 'baz']}, {type => 'string', enum => ['hello']}]},
    additionalProperties => {type => 'integer'},
    },
    E('/', '/propertyName/FOO /anyOf/0 Not in enum list: foo, bar, baz.'),
    E('/', '/propertyName/FOO /anyOf/1 Not in enum list: hello.');
};

subtest 'patternProperties' => sub {
  my $schema = {type => 'object', properties => {name => {type => 'string'}}};
  validate_ok {}, $schema;    # does not matter
  ok !$schema->{patternProperties}, 'patternProperties was not added issue#47';
};

subtest 'propertyNames' => sub {
  my $schema = {propertyNames => {minLength => 3, maxLength => 5}};
  validate_ok {name => 'John', surname => 'Doe'}, $schema, E('/', '/propertyName/surname String is too long: 7/5.');

  $schema->{propertyNames}{maxLength} = 7;
  validate_ok {name => 'John', surname => 'Doe'}, $schema;
};

subtest 'TO_JSON' => sub {
  my $obj = bless {age => 'not_a_string'}, 'main';
  validate_ok $obj, {properties => {age => {type => 'integer'}}},
    E('/age', 'Expected integer - got string.', 'age is not a string');
};

subtest 'const' => sub {
  my $object_constant = {type => 'object', const => {a => 1}};
  validate_ok {a => 1}, $object_constant;
  validate_ok {b => 1}, $object_constant, E('/', q{Does not match const: {"a":1}.});
};

subtest 'boolean schemas' => sub {
  validate_ok {foo => 'bar'}, {type => 'object', required => ['foo'], %$_}
    for ({properties => {foo => {}}}, {additionalProperties => {}}, {patternProperties => {foo => {}}});

  validate_ok {foo => 'bar'},
    {definitions => {my_true_ref => {}}, type => 'object', required => ['foo'], %$_}
    for (
    {properties           => {foo    => {'$ref' => '#/definitions/my_true_ref'}}},
    {additionalProperties => {'$ref' => '#/definitions/my_true_ref'}},
    {patternProperties    => {foo    => {'$ref' => '#/definitions/my_true_ref'}}},
    );

  validate_ok {foo => 'bar'}, {type => 'object', required => ['foo'], %$_}
    for ({properties => {foo => true}}, {additionalProperties => true}, {patternProperties => {foo => true}});

  validate_ok {foo => 'bar'},
    {definitions => {my_true_ref => true}, type => 'object', required => ['foo'], %$_}
    for (
    {properties           => {foo    => {'$ref' => '#/definitions/my_true_ref'}}},
    {additionalProperties => {'$ref' => '#/definitions/my_true_ref'}},
    {patternProperties    => {foo    => {'$ref' => '#/definitions/my_true_ref'}}},
    );

  validate_ok {foo => 'bar'}, {type => 'object', required => ['foo'], %$_}, E('/foo', 'Should not match.')
    for ({properties => {foo => false}}, {patternProperties => {foo => false}});

  validate_ok {foo => 'bar'}, {definitions => {my_false_ref => false}, type => 'object', required => ['foo'], %$_},
    E('/foo', 'Should not match.')
    for (
    {properties           => {foo    => {'$ref' => '#/definitions/my_false_ref'}}},
    {additionalProperties => {'$ref' => '#/definitions/my_false_ref'}},
    {patternProperties    => {foo    => {'$ref' => '#/definitions/my_false_ref'}}},
    );
};

done_testing;

sub TO_JSON { return {age => shift->{age}} }
