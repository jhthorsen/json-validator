use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $v = JSON::Validator->new->schema('data://main/test.schema');
my @errors;

@errors = $v->validate({foo => 'x'});
is "@errors", "/foo: Not in enum list: bar, baz.",
  "fix https://github.com/jhthorsen/json-validator/issues/22";

@errors = $v->validate({foo => 123});
is "@errors", "/foo: Expected string - got number.", "do not check enum if type is wrong";

done_testing;

__DATA__
@@ test.schema
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "title": "test",
  "type": "object",
  "properties": {
    "foo": {"type": "string", "enum": ["bar", "baz"]}
  }
}
