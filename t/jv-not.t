use lib '.';
use t::Helper;

my $schema = {not => {type => 'string'}};

validate_ok 12, $schema;
validate_ok 'str', $schema, E('/', 'Should not match.');

done_testing;
