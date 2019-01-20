use lib '.';
use t::Helper;
use Test::More;

my $schema;

{
  $schema = {type => 'object'};
  validate_ok {mynumber => 1}, $schema;
  validate_ok [1], $schema, E('/', 'Expected object - got array.');
}

{
  $schema->{properties} = {
    number      => {type => 'number'},
    street_name => {type => 'string'},
    street_type => {type => 'string', enum => ['Street', 'Avenue', 'Boulevard']}
  };
  local $schema->{patternProperties}
    = {'^S_' => {type => 'string'}, '^I_' => {type => 'integer'}};

  validate_ok {number => 1600, street_name => 'Pennsylvania',
    street_type => 'Avenue'}, $schema;
  validate_ok {number => '1600', street_name => 'Pennsylvania',
    street_type => 'Avenue'}, $schema,
    E('/number', 'Expected number - got string.');
  validate_ok {number => 1600, street_name => 'Pennsylvania'}, $schema;
  validate_ok {
    number      => 1600,
    street_name => 'Pennsylvania',
    street_type => 'Avenue',
    direction   => 'NW'
  }, $schema;
  validate_ok {'S_25' => 'This is a string', 'I_0' => 42}, $schema;
  validate_ok {'S_0' => 42}, $schema,
    E('/S_0', 'Expected string - got number.');
}

{
  local $TODO = 't/openapi-set-request.t fails because of some oneOf logic';
  my $data = {};
  validate_ok $data,
    {
    type       => 'object',
    properties => {number => {type => 'number', default => 42}}
    };
  is $data->{number}, 42, 'default value was set';
}

{
  local $schema->{additionalProperties} = 0;
  validate_ok {
    number      => 1600,
    street_name => 'Pennsylvania',
    street_type => 'Avenue',
    direction   => 'NW'
    },
    $schema, E('/', 'Properties not allowed: direction.');

  $schema->{additionalProperties} = {type => 'string'};
  validate_ok {
    number      => 1600,
    street_name => 'Pennsylvania',
    street_type => 'Avenue',
    direction   => 'NW'
  }, $schema;
}

{
  local $schema->{required} = ['number', 'street_name'];
  validate_ok {number => 1600, street_type => 'Avenue'}, $schema,
    E('/street_name', 'Missing property.');
}

{
  $schema = {type => 'object', minProperties => 1};
  validate_ok {}, $schema, E('/', 'Not enough properties: 0/1.');
  $schema = {type => 'object', minProperties => 2, maxProperties => 3};
  validate_ok {a => 1}, $schema, E('/', 'Not enough properties: 1/2.');
  validate_ok {a => 1, b => 2}, $schema;
  validate_ok {a => 1, b => 2, c => 3, d => 4}, $schema,
    E('/', 'Too many properties: 4/3.');
}

{
  local $TODO = 'Add support for dependencies';
  $schema = {
    type       => 'object',
    properties => {
      name            => {type => 'string'},
      credit_card     => {type => 'number'},
      billing_address => {type => 'string'},
    },
    required     => ['name'],
    dependencies => {credit_card => ['billing_address']}
  };

  validate_ok {name => 'John Doe', credit_card => 5555555555555555}, $schema,
    E('/credit_card', 'Missing billing_address.', 'credit_card');
}

{
  my $schema = {type => 'object', properties => {name => {type => 'string'}}};
  validate_ok {}, $schema;    # does not matter
  ok !$schema->{patternProperties}, 'patternProperties was not added issue#47';
}

{
  my $schema = {propertyNames => {minLength => 3, maxLength => 5}};
  validate_ok {name => 'John', surname => 'Doe'}, $schema,
    E('/', '/propertyName/surname String is too long: 7/5.');

  $schema->{propertyNames}{maxLength} = 7;
  validate_ok {name => 'John', surname => 'Doe'}, $schema;
}

{
  my $schema = {
    if   => {properties => {ifx => {type      => 'string'}}},
    then => {properties => {ifx => {maxLength => 3}}},
    else => {properties => {ifx => {type      => 'number'}}},
  };

  validate_ok {ifx => 'foo'},    $schema;
  validate_ok {ifx => 'foobar'}, $schema, E('/ifx', 'String is too long: 6/3.');
  validate_ok {ifx => 42},       $schema;
  validate_ok {ifx => []}, $schema, E('/ifx', 'Expected number - got array.');
}

sub TO_JSON { return {age => shift->{age}} }
my $obj = bless {age => 'not_a_string'}, 'main';
validate_ok $obj, {properties => {age => {type => 'integer'}}},
  E('/age', 'Expected integer - got string.', 'age is not a string');

done_testing;
