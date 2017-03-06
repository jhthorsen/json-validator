use lib '.';
use t::Helper;

sub j { Mojo::JSON::decode_json(Mojo::JSON::encode_json($_[0])); }

validate_ok j($_), {type => 'any'} for undef, [], {}, 123, 'foo';
validate_ok j(undef),             {type => 'null'};
validate_ok j(1),                 {type => 'null'}, E('/', 'Not null.');
validate_ok j(Mojo::JSON->false), {type => 'boolean'};
validate_ok j(Mojo::JSON->true),  {type => 'boolean'};
validate_ok j('foo'),             {type => 'boolean'}, E('/', 'Expected boolean - got string.');
validate_ok undef, {properties => {}}, E('/', 'Expected object - got null.');

done_testing;
