use Mojo::Base -strict;
use Test::More;
use JSON::Validator 'validate_json';

my @errors = validate_json(bless({path => '', message => 'yikes'}, 'JSON::Validator::Error'),
  'data://main/spec.json');
ok !@errors, 'TO_JSON on objects' or diag join ', ', @errors;

@errors = validate_json(
  {
    valid  => Mojo::JSON->false,
    errors => [
      bless({path => '', message => 'foo'}, 'JSON::Validator::Error'),
      bless({path => '', message => 'bar'}, 'JSON::Validator::Error')
    ]
  },
  'data://main/spec_array.json'
);
ok !@errors, 'TO_JSON on objects inside arrays' or diag join ', ', @errors;

done_testing;
__DATA__
@@ spec.json
{
  "type": "object",
  "properties": { "message": { "type": "string" } },
  "required": ["message"]
}

@@ spec_array.json
{
  "type": "object",
  "properties": {
    "valid": {
      "type": "boolean"
    },
    "errors": {
      "type": "array",
      "items": {
        "type": "object",
        "properaties": {
          "message": {
            "type": "string"
          },
          "path": {
            "type": "string"
          }
        },
        "required": [ "message" ]
      }
    }
  },
  "required": [
    "errors"
  ]
}
