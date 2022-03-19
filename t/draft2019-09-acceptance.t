use lib '.';
use t::Helper;

$ENV{MOJO_LOG_LEVEL} //= 'fatal';

plan skip_all => 'TEST_ACCEPTANCE=1' unless $ENV{TEST_ACCEPTANCE};
delete $ENV{TEST_ACCEPTANCE} if $ENV{TEST_ACCEPTANCE} eq '1';

my @todo_tests;
push @todo_tests, ['',               'float and integers are equal up to 64-bit representation limits'];
push @todo_tests, ['defs.json',      'validate definition against metaschema'];
push @todo_tests, ['id.json',        '$id inside an enum is not a real identifier'];
push @todo_tests, ['ref.json',       'ref creates new scope when adjacent to keywords'];
push @todo_tests, ['ref.json',       'refs with relative uris and defs'];
push @todo_tests, ['ref.json',       'relative refs with absolute uris and defs'];
push @todo_tests, ['anchor.json',    '$anchor inside an enum is not a real identifier'];
push @todo_tests, ['anchor.json',    'Location-independent identifier with base URI change in subschema'];
push @todo_tests, ['refRemote.json', 'remote ref with ref to defs'];
push @todo_tests, ['recursiveRef.json'];
push @todo_tests, ['unevaluatedItems.json'];
push @todo_tests, ['unevaluatedProperties.json'];
push @todo_tests, ['unknownKeyword.json', '$id inside an unknown keyword is not a real identifier'];
push @todo_tests, ['vocabulary.json',     'schema that uses custom metaschema with with no validation vocabulary'];

t::Helper->acceptance('JSON::Validator::Schema::Draft201909', todo_tests => \@todo_tests);

done_testing;
