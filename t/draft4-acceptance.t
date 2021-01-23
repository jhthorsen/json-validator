use lib '.';
use t::Helper;

plan skip_all => 'TEST_ACCEPTANCE=1' unless $ENV{TEST_ACCEPTANCE};

t::Helper->acceptance('JSON::Validator::Schema::Draft4');

done_testing;
