use lib '.';
use t::Helper;

plan skip_all => 'TEST_ACCEPTANCE=1' unless $ENV{TEST_ACCEPTANCE};
delete $ENV{TEST_ACCEPTANCE} if $ENV{TEST_ACCEPTANCE} eq '1';

my @todo_tests;
push @todo_tests, ['',               'float and integers are equal up to 64-bit representation limits'];
push @todo_tests, ['defs.json',      'invalid definition'];
push @todo_tests, ['ref.json',       'ref creates new scope when adjacent to keywords'];
push @todo_tests, ['ref.json',       'remote ref, containing refs itself', 'remote ref invalid'];
push @todo_tests, ['anchor.json',    'Location-independent identifier with base URI change in subschema'];
push @todo_tests, ['refRemote.json', 'remote ref'];
push @todo_tests, ['recursiveRef.json'];
push @todo_tests, ['unevaluatedItems.json'];
push @todo_tests, ['unevaluatedProperties.json'];

t::Helper->acceptance('JSON::Validator::Schema::Draft201909', todo_tests => \@todo_tests);

done_testing;
