use lib '.';
use t::Helper;

validate_ok {who_id => 'WHO', expire => '2018-01-01', amount => 1000,
  desc => 'foo'}, 'data://main/example.json',
  E('/sym',      '/oneOf/0/allOf/0/allOf/0 Missing property.'),
  E('/template', '/oneOf/0/allOf/2 Missing property.'),
  E('/sym',      '/oneOf/1/allOf/0 Missing property.');

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
