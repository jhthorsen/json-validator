use lib '.';
use t::Helper;

my $schema = {
  type => 'object',
  properties =>
    {mynumber => {type => 'number', minimum => -0.5, maximum => 2.7}}
};

validate_ok {mynumber => 1},   $schema;
validate_ok {mynumber => '2'}, $schema,
  E('/mynumber', 'Expected number - got string.');

my $numeric_constant = {type => 'number', const => 2.1};
validate_ok 2.1, $numeric_constant;
validate_ok 1, $numeric_constant, E('/', q{Does not match const: 2.1.});

jv->coerce('numbers');
validate_ok {mynumber => '-0.3'},   $schema;
validate_ok {mynumber => '0.1e+1'}, $schema;
validate_ok {mynumber => '2xyz'},   $schema,
  E('/mynumber', 'Expected number - got string.');
validate_ok {mynumber => '.1'}, $schema,
  E('/mynumber', 'Expected number - got string.');
validate_ok {validNumber => 2.01},
  {
  type       => 'object',
  properties => {validNumber => {type => 'number', multipleOf => 0.01}}
  };

validate_ok '2.1', $numeric_constant;
validate_ok '1', $numeric_constant, E('/', q{Does not match const: 2.1.});

done_testing;
