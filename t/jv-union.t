use Mojo::Base -strict;
use Test::More;
use Swagger2::SchemaValidator;
use Mojo::JSON;

my $validator = Swagger2::SchemaValidator->new;

my $schema1 = {
  type                 => 'object',
  additionalProperties => 0,
  properties           => {test => {type => ['boolean', 'integer'], required => 1}}
};

my $schema2 = {
  type                 => 'object',
  additionalProperties => 0,
  properties           => {
    test => {
      type => [
        {type => "object", additionalProperties => 0, properties => {dog => {type => "string", required => 1}}},
        {
          type                 => "object",
          additionalProperties => 0,
          properties           => {sound => {type => 'string', enum => ["bark", "meow", "squeak"], required => 1}}
        }
      ],
      required => 1
    }
  }
};

my $schema3 = {
  type                 => 'object',
  additionalProperties => 0,
  properties           => {test => {type => [qw/object array string number integer boolean null/], required => 1}}
};

my @errors = $validator->validate({test => "strang"}, $schema1);
is "@errors", "/test: Expected boolean, integer - got string.", 'boolean or integer against string';

@errors = $validator->validate({test => 1}, $schema1);
is "@errors", "", 'boolean or integer against integer';

@errors = $validator->validate({test => ['array']}, $schema1);
is "@errors", "/test: Expected boolean, integer - got array.", 'boolean or integer against array';

@errors = $validator->validate({test => {object => 'yipe'}}, $schema1);
is "@errors", "/test: Expected boolean, integer - got object.", 'boolean or integer against object';

@errors = $validator->validate({test => 1.1}, $schema1);
is "@errors", "/test: Expected boolean, integer - got number.", 'boolean or integer against number';

@errors = $validator->validate({test => !!1}, $schema1);
is "@errors", "", 'boolean or integer against boolean';

@errors = $validator->validate({test => undef}, $schema1);
is "@errors", "/test: Expected boolean, integer - got null.", 'boolean or integer against null';

@errors = $validator->validate({test => {dog => "woof"}}, $schema2);
is "@errors", "", 'object or object against object a';

@errors = $validator->validate({test => {sound => "meow"}}, $schema2);
is "@errors", "", 'object or object against object b nested enum pass';

@errors = $validator->validate({test => {sound => "oink"}}, $schema2);
is $errors[0], '/test: [0] Properties not allowed: sound. [1] Not in enum list: bark, meow, squeak.', '/test';
is $errors[1], '/test/dog: [0] Missing property.', '/test/dog';

@errors = $validator->validate({test => {audible => "meow"}}, $schema2);
is $errors[0], '/test: [0] Properties not allowed: audible.', '/test';
is $errors[1], '/test/dog: [0] Missing property.',            '/test/dog';
is $errors[2], '/test/sound: [1] Missing property.',          '/test/sound';

@errors = $validator->validate({test => 2}, $schema2);
is "@errors", "/test: Expected object - got integer.", "object or object against integer";

@errors = $validator->validate({test => 2.2}, $schema2);
is "@errors", "/test: Expected object - got number.", "object or object against number";

@errors = $validator->validate({test => Mojo::JSON->true}, $schema2);
is "@errors", "/test: Expected object - got boolean.", "object or object against boolean";

@errors = $validator->validate({test => undef}, $schema2);
is "@errors", "/test: Expected object - got null.", "object or object against null";

@errors = $validator->validate({test => {dog => undef}}, $schema2);
is $errors[0], "/test: [1] Properties not allowed: dog.", "object or object against object a bad inner type";
is $errors[1], "/test/dog: Expected string - got null.",  "object or object against object a bad inner type";
is $errors[2], "/test/sound: [1] Missing property.",      "object or object against object a bad inner type";

@errors = $validator->validate({test => {dog => undef}}, $schema3);
is "@errors", "", 'all types against object';

@errors = $validator->validate({test => ['dog']}, $schema3);
is "@errors", "", 'all types against array';

@errors = $validator->validate({test => 'dog'}, $schema3);
is "@errors", "", 'all types against string';

@errors = $validator->validate({test => 1.1}, $schema3);
is "@errors", "", 'all types against number';

@errors = $validator->validate({test => 1}, $schema3);
is "@errors", "", 'all types against integer';

@errors = $validator->validate({test => 1}, $schema3);
is "@errors", "", 'all types against boolean';

@errors = $validator->validate({test => undef}, $schema3);
is "@errors", "", 'all types against null';

done_testing;
