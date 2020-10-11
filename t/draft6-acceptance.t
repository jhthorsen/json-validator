use lib '.';
use t::Helper;

my @todo_tests;
push @todo_tests, ['const.json', 'float and integers are equal up to 64-bit representation limits'];

t::Helper->acceptance('JSON::Validator::Schema::Draft6', todo_tests => \@todo_tests);

done_testing;
