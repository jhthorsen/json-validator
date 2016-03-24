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

# Alternative oneOf
# http://json-schema.org/latest/json-schema-validation.html#anchor79
$schema
  = {type => 'object', properties => {x => {type => ['string', 'null'], format => 'date-time'}}};
@errors = $validator->validate({x => 'foo'}, $schema);
is "@errors", "/x: ([0] Does not match date-time format. [1] Not null.)", "foo";

@errors = $validator->validate({x => '2015-04-21T20:30:43.000Z'}, $schema);
is "@errors", "", "YYYY-MM-DDThh:mm:ss.fffZ";

@errors = $validator->validate({x => undef}, $schema);
is "@errors", "", "null";

done_testing;
