use lib '.';
use t::Helper;
use Test::More;

my $validator = JSON::Validator->new->schema('data://main/example.json');

my @errors
  = $validator->validate({who_id => 'WHO', expire => '2018-01-01', amount => 1000, desc => 'foo'});

like "@errors", qr{oneOf failed}, "missing sym is not detected (@errors)";
note map {"\$errors[] = $_\n"} @errors;

done_testing;

__DATA__
@@ example.json
{
  "oneOf": [
    {"$ref": "#/definitions/template_1"},
    {"$ref": "#/definitions/bar_header"}
  ],
  "definitions": {
    "hwho":{
      "required": [ "who_id" ],
      "properties": {
        "who_id": { "type": "string" },
        "sub_who_id": { "type": "string" }
      }
    },
    "header": {
      "required": [ "sym", "expire" ],
      "properties": {
        "sym": { "type": "string" },
        "expire": { "type": "string" }
      }
    },
    "foo_header": {
      "allOf": [
        { "$ref": "#/definitions/header" },
        {
          "required": [ "amount", "desc" ],
          "properties": {
            "amount": { "type": "integer" },
            "desc": { "enum": [ "foo" ] }
          }
        }
      ]
    },
    "template_1": {
      "allOf": [
        { "$ref": "#/definitions/foo_header" },
        { "$ref": "#/definitions/hwho" },
        { "required": [ "template" ], "properties": { "template": { "type": "string" } } }
      ]
    },
    "bar_header" : {
      "allOf": [
        { "$ref": "#/definitions/header" },
        {
          "required": [ "amount", "desc" ],
          "properties": {
            "amount": { "type": "integer" },
            "desc": { "enum": [ "foo" ] }
          }
        }
      ]
    }
  }
}
