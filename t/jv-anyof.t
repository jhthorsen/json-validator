use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new;
my $schema = {anyOf => [{type => "string", maxLength => 5}, {type => "number", minimum => 0}]};
my @errors;

@errors = $validator->validate("short", $schema);
is "@errors", "", "short";

@errors = $validator->validate("too long", $schema);
is "@errors", "/: anyOf failed: ([0] String is too long: 8/5. [1] Expected number - got string.)", "too long";

@errors = $validator->validate(12, $schema);
is "@errors", "", "number";

@errors = $validator->validate(-1, $schema);
is "@errors", "/: anyOf failed: ([0] Expected string - got number. [1] -1 < minimum(0))", "negative";

done_testing;
