use lib '.';
use t::Helper;

my @todo_tests;
t::Helper->acceptance('JSON::Validator::Schema::Draft201909', todo_tests => \@todo_tests);

done_testing;
