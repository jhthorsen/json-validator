use lib '.';
use t::Helper;

my $schema;

$schema = {
  if   => {properties => {ifx => {type      => 'string'}}},
  then => {properties => {ifx => {maxLength => 3}}},
  else => {properties => {ifx => {type      => 'number'}}},
};

validate_ok {ifx => 'foo'},    $schema;
validate_ok {ifx => 'foobar'}, $schema, E('/ifx', 'String is too long: 6/3.');
validate_ok {ifx => 42},       $schema;
validate_ok {ifx => []}, $schema, E('/ifx', 'Expected number - got array.');

$schema = {
  type => 'array',
  if   => {maxItems => 5},
  then => {items => {pattern => '^[0-9]$'}},
  else => {items => {pattern => '^[a-z]$'}},
};

validate_ok [qw(2 4 7)], $schema;
validate_ok [qw(a 1)], $schema, E('/0', 'String does not match ^[0-9]$.');
validate_ok [qw(6 q a b 8 z)], $schema,
  E('/0', 'String does not match ^[a-z]$.'),
  E('/4', 'String does not match ^[a-z]$.');

done_testing;
