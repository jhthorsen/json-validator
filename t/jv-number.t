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

t::Helper->validator->coerce(numbers => 1);
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

done_testing;
