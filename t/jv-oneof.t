use Mojo::Base -strict;
use Test::More;
use Swagger2::SchemaValidator;

my $validator = Swagger2::SchemaValidator->new;
my $schema = {oneOf => [{type => "string", maxLength => 5}, {type => "number", minimum => 0}]};
my @errors;

@errors = $validator->validate("short", $schema);
is "@errors", "", "string";
@errors = $validator->validate(12, $schema);
is "@errors", "", "number";

$schema = {oneOf => [{type => "number", multipleOf => 5}, {type => "number", multipleOf => 3}]};
@errors = $validator->validate(10, $schema);
is "@errors", "", "n:10";
@errors = $validator->validate(9, $schema);
is "@errors", "", "n:9";
@errors = $validator->validate(15, $schema);
is "@errors", "/: Expected only one to match.", "n:15";

done_testing;
