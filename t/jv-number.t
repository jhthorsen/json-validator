use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new;
my $schema
  = {type => 'object', properties => {mynumber => {type => 'number', minimum => -0.5, maximum => 2.7}}};

my @errors = $validator->validate({mynumber => 1}, $schema);
is "@errors", "", "number";

@errors = $validator->validate({mynumber => "2"}, $schema);
is "@errors", "/mynumber: Expected number - got string.", "a string";

$validator->coerce(numbers => 1);
@errors = $validator->validate({mynumber => "-0.3"}, $schema);
is "@errors", "", "coerced string into number";

@errors = $validator->validate({mynumber => "0.1e+1"}, $schema);
is "@errors", "", "coerced scientific notation";

@errors = $validator->validate({mynumber => "2xyz"}, $schema);
is "@errors", "/mynumber: Expected number - got string.", "a string";

@errors = $validator->validate({mynumber => ".1"}, $schema);
is "@errors", "/mynumber: Expected number - got string.", "not a JSON number";

done_testing;
