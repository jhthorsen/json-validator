use lib '.';
use t::Helper;

my @todo_tests;
push @todo_tests, ['', 'Invalid use of fragments in location-independent $id'];
push @todo_tests, ['', 'Location-independent identifier with absolute URI'];
push @todo_tests, ['', 'Location-independent identifier with base URI change in subschema'];
push @todo_tests, ['', 'float and integers are equal up to 64-bit representation limits'];
push @todo_tests, ['ref.json'];
push @todo_tests, ['refRemote.json'];

#push @todo_tests, ['dependentRequired.json'];
#push @todo_tests, ['dependentSchemas.json'];
#push @todo_tests, ['unevaluatedItems.json'];
#push @todo_tests, ['unevaluatedProperties.json'];

#push @todo_tests, ['defs.json'];

t::Helper->acceptance('JSON::Validator::Schema::Draft201909', todo_tests => \@todo_tests);

done_testing;
