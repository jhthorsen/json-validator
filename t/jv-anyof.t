use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new;
my $schema = {anyOf => [{type => "string", maxLength => 5}, {type => "number", minimum => 0}]};
my @errors;

@errors = $validator->validate("short", $schema);
is "@errors", "", "short";

@errors = $validator->validate("too long", $schema);
is "@errors", "/: anyOf failed: String is too long: 8/5.", "too long";

@errors = $validator->validate(12, $schema);
is "@errors", "", "number";

@errors = $validator->validate(-1, $schema);
is "@errors", "/: anyOf failed: -1 < minimum(0)", "negative";

@errors = $validator->validate({}, $schema);
is "@errors", "/: anyOf failed: Expected something else than object.", "object";

# anyOf with schema of the same 'type'

# anyOf with explicit integer (where _guess_data_type returns 'number')
my $schemaB = {anyOf => [{type => "integer"}, {minimum => 2}]};

@errors = $validator->validate(1 ,$schemaB);
is "@errors", "", "schema 1 pass, schema 2 faili";

done_testing;
