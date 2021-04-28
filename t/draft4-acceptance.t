use lib '.';
use t::Helper;

$ENV{MOJO_LOG_LEVEL} //= 'fatal';

plan skip_all => 'TEST_ACCEPTANCE=1' unless $ENV{TEST_ACCEPTANCE};
delete $ENV{TEST_ACCEPTANCE} if $ENV{TEST_ACCEPTANCE} eq '1';

my @todo_tests;
push @todo_tests, ['id.json', 'id inside an enum is not a real identifier'];

t::Helper->acceptance('JSON::Validator::Schema::Draft4', todo_tests => \@todo_tests);

done_testing;
