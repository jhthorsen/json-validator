use lib '.';
use t::Helper;

plan skip_all => 'TEST_ACCEPTANCE=1' unless $ENV{TEST_ACCEPTANCE};
delete $ENV{TEST_ACCEPTANCE} if $ENV{TEST_ACCEPTANCE} eq '1';

t::Helper->acceptance('JSON::Validator::Schema::Draft4');

done_testing;
