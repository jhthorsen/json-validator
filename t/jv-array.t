use Mojo::Base -strict;
use Test::More;
use Swagger2::SchemaValidator;
use Mojo::JSON;

my $validator = Swagger2::SchemaValidator->new;
my @errors;

my $simple = {type => "array", items => {type => "number"}};
my $length = {type => "array", minItems => 2, maxItems => 2};
my $unique = {type => 'array', uniqueItems => 1, items => {type => 'integer'}};
my $tuple = {
  type  => "array",
  items => [
    {type => "number"},
    {type => "string"},
    {type => "string", enum => ["Street", "Avenue", "Boulevard"]},
    {type => "string", enum => ["NW", "NE", "SW", "SE"]}
  ]
};

@errors = $validator->validate([1], $simple);
is "@errors", "", "simple: success";
@errors = $validator->validate([1, "foo"], $simple);
is "@errors", "/1: Expected number - got string.", "simple: got string";

@errors = $validator->validate([1], $length);
is "@errors", "/: Not enough items: 1/2.", "length: not enough";
@errors = $validator->validate([1, 2], $length);
is "@errors", "", "length: success";
@errors = $validator->validate([1, 2, 3], $length);
is "@errors", "/: Too many items: 3/2.", "length: too many";

@errors = $validator->validate([123, 124], $unique);
is "@errors", "", "unique: success";
@errors = $validator->validate([1, 2, 1], $unique);
is "@errors", "/: Unique items required.", "unique: fail";

@errors = $validator->validate([1600, "Pennsylvania", "Avenue", "NW"], $tuple);
is "@errors", "", "tuple: success";
@errors = $validator->validate([24, "Sussex", "Drive"], $tuple);
is "@errors", "", "tuple: invalid";
@errors = $validator->validate([10, "Downing", "Street"], $tuple);
is "@errors", "", "tuple: not complete length";
@errors = $validator->validate([1600, "Pennsylvania", "Avenue", "NW", "Washington"], $tuple);
is "@errors", "", "tuple: too many";

$tuple->{additionalItems} = Mojo::JSON->false;
@errors = $validator->validate([1600, "Pennsylvania", "Avenue", "NW", "Washington"], $tuple);
is "@errors", "/: Invalid number of items: 5/4.", "tuple: additionalItems";

done_testing;
