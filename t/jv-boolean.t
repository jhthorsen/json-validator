use lib '.';
use t::Helper;

sub j { Mojo::JSON::decode_json(Mojo::JSON::encode_json($_[0])); }

my $schema = {type => 'object', properties => {nick => {type => 'boolean'}}};

validate_ok {nick => true}, $schema;
validate_ok {nick => 1000}, $schema,
  E('/nick', 'Expected boolean - got number.');
validate_ok {nick => 0.5}, $schema,
  E('/nick', 'Expected boolean - got number.');
validate_ok {nick => 'nick'}, $schema,
  E('/nick', 'Expected boolean - got string.');
validate_ok {nick => bless({}, 'BoolTestOk')},   $schema;
validate_ok {nick => bless({}, 'BoolTestFail')}, $schema,
  E('/nick', 'Expected boolean - got BoolTestFail.');

validate_ok j(Mojo::JSON->false), {type => 'boolean'};
validate_ok j(Mojo::JSON->true),  {type => 'boolean'};
validate_ok j('foo'),             {type => 'boolean'},
  E('/', 'Expected boolean - got string.');
validate_ok undef, {properties => {}}, E('/', 'Expected object - got null.');

my $bool_constant_false = {type => 'boolean', const => false};
my $bool_constant_true  = {type => 'boolean', const => true};
validate_ok false, $bool_constant_false;
validate_ok true, $bool_constant_false, E('/', q{Does not match const: false.});
validate_ok true, $bool_constant_true;
validate_ok false, $bool_constant_true, E('/', q{Does not match const: true.});

jv->coerce('bool');
validate_ok {nick => 1000}, $schema;
validate_ok {nick => 0.5},  $schema;

validate_ok 0,    $bool_constant_false;
validate_ok 1000, $bool_constant_false, E('/', q{Does not match const: false.});
validate_ok 1000, $bool_constant_true;
validate_ok 0,    $bool_constant_true, E('/', q{Does not match const: true.});

done_testing;

package BoolTestOk;
use overload '""' => sub {1};

package BoolTestFail;
use overload '""' => sub {2};
