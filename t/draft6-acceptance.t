use lib '.';
use t::Helper;

$ENV{MOJO_LOG_LEVEL} //= 'fatal';

plan skip_all => 'TEST_ACCEPTANCE=1' unless $ENV{TEST_ACCEPTANCE};
delete $ENV{TEST_ACCEPTANCE} if $ENV{TEST_ACCEPTANCE} eq '1';

my @todo_tests;
push @todo_tests, ['const.json',          'float and integers are equal up to 64-bit representation limits'];
push @todo_tests, ['id.json',             'id inside an enum is not a real identifier'];
push @todo_tests, ['maxItems.json',       'maxItems validation with a decimal'];
push @todo_tests, ['maxLength.json',      'maxLength validation with a decimal'];
push @todo_tests, ['maxProperties.json',  'maxProperties validation with a decimal'];
push @todo_tests, ['minItems.json',       'minItems validation with a decimal'];
push @todo_tests, ['minLength.json',      'minLength validation with a decimal'];
push @todo_tests, ['minProperties.json',  'minProperties validation with a decimal'];
push @todo_tests, ['ref.json',            '$ref prevents a sibling $id from changing the base uri'];
push @todo_tests, ['refRemote.json',      'remote ref with ref to definitions'];
push @todo_tests, ['refRemote.json',      'Location-independent identifier in remote ref'];
push @todo_tests, ['unknownKeyword.json', '$id inside an unknown keyword is not a real identifier'];

t::Helper->acceptance('JSON::Validator::Schema::Draft6', todo_tests => \@todo_tests);

done_testing;
