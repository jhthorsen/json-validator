use lib '.';
use t::Helper;

my @todo_tests;
push @todo_tests, ['const.json', 'float and integers are equal up to 64-bit representation limits'];
push @todo_tests, ['ref.json',   'Location-independent identifier with base URI change in subschema'];
push @todo_tests, ['refRemote.json'];

t::Helper->acceptance('JSON::Validator::Schema::Draft6', todo_tests => \@todo_tests);

done_testing;
