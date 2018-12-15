use Mojo::Base -strict;
use Test::More;
use JSON::Validator 'validate_json';

my @errors
  = validate_json(
  bless({path => '', message => 'yikes'}, 'JSON::Validator::Error'),
  'data://main/error_object.json');
ok !@errors, 'TO_JSON on objects' or diag join ', ', @errors;

my $input = {
  errors => [
    JSON::Validator::Error->new('/', 'foo'),
    JSON::Validator::Error->new('/', 'bar')
  ],
  valid => Mojo::JSON->false,
};
@errors = validate_json $input, 'data://main/error_array.json';
ok !@errors, 'TO_JSON on objects inside arrays' or diag join ', ', @errors;
is_deeply $input,
  {
  errors => [
    JSON::Validator::Error->new('/', 'foo'),
    JSON::Validator::Error->new('/', 'bar')
  ],
  valid => Mojo::JSON->false,
  },
  'input objects are not changed';

done_testing;
__DATA__
@@ error_object.json
{
  "type": "object",
  "properties": { "message": { "type": "string" } },
  "required": ["message"]
}

@@ error_array.json
{
  "type": "object",
  "required": [ "errors" ],
  "properties": {
    "valid": { "type": "boolean" },
    "errors": {
      "type": "array",
      "items": {
        "type": "object",
        "required": [ "message" ],
        "properaties": {
          "message": { "type": "string" },
          "path": { "type": "string" }
        }
      }
    }
  }
}
