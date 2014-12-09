use Mojo::Base -strict;
use Test::More;
use Swagger2::SchemaValidator;

my $validator = Swagger2::SchemaValidator->new;
my $schema = {allOf => [{type => "string", maxLength => 5}, {type => "number", minimum => 0}]};
my @errors;

@errors = $validator->validate("short", $schema);
is "@errors", "/: Expected number - got string.", "got string";
@errors = $validator->validate(12, $schema);
is "@errors", "/: Expected string - got number.", "got number";

$schema = {allOf => [{type => "string", maxLength => 7}, {type => "string", maxLength => 5}]};
@errors = $validator->validate("toolong", $schema);
is "@errors", "/: [1] String is too long: 7/5.", "too long";
@errors = $validator->validate("short", $schema);
is "@errors", "", "success";

done_testing;
