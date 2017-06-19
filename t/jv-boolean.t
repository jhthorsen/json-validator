use lib '.';
use t::Helper;

my $schema = {
  type       => 'object',
  properties => {nick => {type => 'boolean'}}
};

validate_ok {nick => true}, $schema;
validate_ok {nick => 1000},       $schema, E('/nick', 'Expected boolean - got number.');
validate_ok {nick => 0.5},        $schema, E('/nick', 'Expected boolean - got number.');
validate_ok {nick => 'nick'},     $schema, E('/nick', 'Expected boolean - got string.');
validate_ok {nick => bless({}, 'BoolTest')},   $schema;
validate_ok {nick => bless({}, 'BoolTestNegative')},   $schema, E('/nick', 'Expected boolean - got BoolTestNegative.');

t::Helper->validator->coerce(1);
validate_ok {nick => 1000}, $schema;
validate_ok {nick => 0.5}, $schema;

done_testing;

package BoolTest;

use overload '""' => sub { 1 };

package BoolTestNegative;

use overload '""' => sub { 2 };
