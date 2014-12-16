use Mojo::Base -strict;
use Test::More;
use Swagger2::SchemaValidator;

my $validator = Swagger2::SchemaValidator->new;
my $schema = {not => {type => "string"}};
my @errors;

local $TODO = '"not" is not working';

@errors = $validator->validate(12, $schema);
is "@errors", "", "not string";
@errors = $validator->validate("str", $schema);
is "@errors", "/: Should not match.", "is string";

done_testing;
