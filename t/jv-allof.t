use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new;
my $schema = {allOf => [{type => "string", maxLength => 5}, {type => "string", minLength => 3}]};
my @errors;

@errors = $validator->validate("short", $schema);
is "@errors", "", "got string";
@errors = $validator->validate(12, $schema);
is "@errors", "/: allOf failed: Expected string, not number.", "got number";

$schema = {allOf => [{type => "string", maxLength => 7}, {type => "string", maxLength => 5}]};
@errors = $validator->validate("superlong", $schema);
is "@errors", "/: allOf failed: String is too long: 9/7. String is too long: 9/5.", "super long";
@errors = $validator->validate("toolong", $schema);
is "@errors", "/: allOf failed: String is too long: 7/5.", "too long";
@errors = $validator->validate("short", $schema);
is "@errors", "", "success";

done_testing;
