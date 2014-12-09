use Mojo::Base -strict;
use Test::More;
use Swagger2::SchemaValidator;

my $validator = Swagger2::SchemaValidator->new;
my $schema1   = {type => 'object', properties => {mynumber => {type => 'string', required => 1}}};
my $schema2   = {type => 'object', properties => {mynumber => {type => 'string', required => 0}}};

my $data1 = {mynumber => "yay"};
my $data2 = {mynumbre => "err"};

my @errors = $validator->validate($data1, $schema1);
is "@errors", "", "data1, schema1";

@errors = $validator->validate($data2, $schema1);
is "@errors", "/mynumber: Missing property.", "data2, schema1";

@errors = $validator->validate($data1, $schema2);
is "@errors", "", "data1, schema2";

@errors = $validator->validate($data2, $schema2);
is "@errors", "", "data2, schema2";

done_testing;

