use Mojo::Base -strict;
use Test::More;
use JSON::Validator 'validate_json';

my $schema0 = {type => 'object', properties => {mynumber => {type => 'string', required => 1}}};
my $schema1 = {type => 'object', properties => {mynumber => {type => 'string'}}, required => ['mynumber']};
my $schema2 = {type => 'object', properties => {mynumber => {type => 'string'}}};

my $data1 = {mynumber => "yay"};
my $data2 = {mynumbre => "err"};

my @errors = validate_json $data1, $schema1;
is "@errors", "", "data1, schema1";

@errors = validate_json $data2, $schema0;
is "@errors", "/mynumber: Missing property.", "data2, schema1";

@errors = validate_json $data2, $schema1;
is "@errors", "/mynumber: Missing property.", "data2, schema1";

@errors = validate_json $data1, $schema2;
is "@errors", "", "data1, schema2";

@errors = validate_json $data2, $schema2;
is "@errors", "", "data2, schema2";

done_testing;

