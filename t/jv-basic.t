use lib '.';
use t::Helper;

sub j { Mojo::JSON::decode_json(Mojo::JSON::encode_json($_[0])); }

validate_ok j($_), {type => 'any'} for undef, [], {}, 123, 'foo';
validate_ok j(undef), {type => 'null'};
validate_ok j(1), {type => 'null'}, E('/', 'Not null.');

done_testing;
