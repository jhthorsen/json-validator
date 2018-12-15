use lib '.';
use t::Helper;

my $schema0 = {
  type       => 'object',
  properties => {mynumber => {type => 'string', required => 1}}
};
my $schema1 = {
  type       => 'object',
  properties => {mynumber => {type => 'string'}},
  required   => ['mynumber']
};
my $schema2
  = {type => 'object', properties => {mynumber => {type => 'string'}}};

my $data1 = {mynumber => 'yay'};
my $data2 = {mynumbre => 'err'};

validate_ok $data1, $schema1;
validate_ok $data2, $schema0;    # Cannot have required on properties
validate_ok $data2, $schema1, E('/mynumber', 'Missing property.');
validate_ok $data1, $schema2;
validate_ok $data2, $schema2;

done_testing;
