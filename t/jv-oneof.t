use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new;
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
is "@errors", "/: All of the oneOf rules match.", "n:15";
@errors = $validator->validate(13, $schema);
is "@errors", "/: oneOf failed: Not multiple of 5. Not multiple of 3.", "n:13";

$schema = {oneOf => [{type => "object"}, {type => "string", multipleOf => 3}]};
@errors = $validator->validate(13, $schema);
is "@errors", "/: oneOf failed: Expected object or string, got number.", "n:13 object/string";

$schema = {oneOf => [{type => "object"}, {type => "number", multipleOf => 3}]};
@errors = $validator->validate(13, $schema);
is "@errors", "/: oneOf failed: Not multiple of 3.", "multipleOf";

# Alternative oneOf
# http://json-schema.org/latest/json-schema-validation.html#anchor79
$schema
  = {type => 'object', properties => {x => {type => ['string', 'null'], format => 'date-time'}}};
@errors = $validator->validate({x => 'foo'}, $schema);
is "@errors", "/x: anyOf[0]: Does not match date-time format.", "date-time";
@errors = $validator->validate({x => '2015-04-21T20:30:43.000Z'}, $schema);
is "@errors", "", "YYYY-MM-DDThh:mm:ss.fffZ";
@errors = $validator->validate({x => undef}, $schema);
is "@errors", "", "null";

done_testing;
