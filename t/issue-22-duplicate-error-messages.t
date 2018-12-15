use lib '.';
use t::Helper;

# https://github.com/jhthorsen/json-validator/issues/22
validate_ok {foo => 'x'}, 'data://main/test.schema',
  E('/foo', 'Not in enum list: bar, baz.');
validate_ok {foo => 123}, 'data://main/test.schema',
  E('/foo', 'Expected string - got number.');

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
