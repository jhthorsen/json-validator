use Mojo::Base -strict;
use JSON::Validator;
use Test::More;

my $schema = JSON::Validator->new->schema('data://main/spec.json')->schema;
my @errors;

@errors = $schema->validate_request([get => '/pets/{id}'], {path => {id => '42'}});
is "@errors", "", 'collectionFormat csv in path';

for ([csv => ","], [pipes => "|"], [ssv => " "], [tsv => "\t"]) {
  my ($name, $sep) = @$_;
  my $empty = $name =~ m!^pipes! ? '' : '0';

  @errors = $schema->validate_request([get => '/pets'], {query => {"${name}0" => $empty, multir => ''}});
  is "@errors", "", "collectionFormat ${name}0 empty string";

  @errors = $schema->validate_request([get => '/pets'], {query => {"${name}0" => '42', multir => ''}});
  is "@errors", "", "collectionFormat ${name}0 single item";

  @errors = $schema->validate_request([get => '/pets'], {query => {"${name}0" => "4${sep}2", multir => ''}});
  is "@errors", "", "collectionFormat ${name}0 two item";

  @errors = $schema->validate_request([get => '/pets'], {query => {"${name}2" => '42', multir => ''}});
  is "@errors", "/${name}2: Not enough items: 1/2.", "collectionFormat ${name}2 single item";
}

done_testing;

__DATA__
@@ spec.json
{
  "swagger": "2.0",
  "info": {"version": "", "title": "Test collectionFormat"},
  "basePath": "/api",
  "paths": {
    "/pets/{id}": {
      "get": {
        "parameters": [
          {"name": "id", "in": "path", "type": "array", "collectionFormat": "csv", "items": {"type": "string"}, "minItems": 0, "required": true}
        ],
        "responses": {
          "200": {
            "description": "pet response",
            "schema": {"type": "object"}
          }
        }
      }
    },
    "/pets": {
      "get": {
        "parameters": [
          {"name": "csv", "in": "query", "type": "array", "collectionFormat": "csv", "items": {"type": "number"}, "minItems": 0, "default": []},
          {"name": "csv0", "in": "query", "type": "array", "collectionFormat": "csv", "items": {"type": "number"}, "minItems": 0},
          {"name": "csv2", "in": "query", "type": "array", "collectionFormat": "csv", "items": {"type": "number"}, "minItems": 2},
          {"name": "multi", "in": "query", "type": "array", "collectionFormat": "multi", "items": {"type": "integer"}, "minItems": 0, "default": []},
          {"name": "multi0", "in": "query", "type": "array", "collectionFormat": "multi", "items": {"type": "integer"}, "minItems": 0},
          {"name": "multi2", "in": "query", "type": "array", "collectionFormat": "multi", "items": {"type": "integer"}, "minItems": 2},
          {"name": "multir", "in": "query", "type": "array", "collectionFormat": "multi", "required": true, "items": {"type": "string"}, "minItems":1},
          {"name": "pipes", "in": "query", "type": "array", "collectionFormat": "pipes", "items": {"type": "string"}, "minItems": 0, "default": []},
          {"name": "pipes0", "in": "query", "type": "array", "collectionFormat": "pipes", "items": {"type": "string"}, "minItems": 0},
          {"name": "pipes2", "in": "query", "type": "array", "collectionFormat": "pipes", "items": {"type": "integer"}, "minItems": 2},
          {"name": "ssv", "in": "query", "type": "array", "collectionFormat": "ssv", "items": {"type": "number"}, "minItems": 0, "default": []},
          {"name": "ssv0", "in": "query", "type": "array", "collectionFormat": "ssv", "items": {"type": "number"}, "minItems": 0},
          {"name": "ssv2", "in": "query", "type": "array", "collectionFormat": "ssv", "items": {"type": "number"}, "minItems": 2},
          {"name": "tsv", "in": "query", "type": "array", "collectionFormat": "tsv", "items": {"type": "integer"}, "minItems": 0, "default": []},
          {"name": "tsv0", "in": "query", "type": "array", "collectionFormat": "tsv", "items": {"type": "integer"}, "minItems": 0},
          {"name": "tsv2", "in": "query", "type": "array", "collectionFormat": "tsv", "items": {"type": "integer"}, "minItems": 2}
        ],
        "responses": {
          "200": {
            "description": "pet response",
            "schema": {"type": "object"}
          }
        }
      }
    }
  }
}
