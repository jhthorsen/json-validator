use Mojo::Base -strict;
use JSON::Validator;
use Test::More;

my $schema = JSON::Validator->new->schema('data://main/spec.json')->schema;
my ($body, @errors);

for my $path (qw(/nullable-data /nullable-ref)) {
  $body   = {exists => 1, value => {id => 42}};
  @errors = $schema->validate_response([get => $path], {body => \&body});
  is "@errors", "/body/name: Missing property.", "$path - missing name";

  $body   = {exists => 1, value => {id => 42, name => undef}};
  @errors = $schema->validate_response([get => $path], {body => \&body});
  is "@errors", "", "$path - name is undef";
}

for my $extra ({}, undef) {
  $body   = {exists => 1, value => {extra => $extra, id => 42, name => undef}};
  @errors = $schema->validate_response([get => '/nullable-data'], {body => \&body});
  is "@errors", "", sprintf 'extra %s', $extra ? 'object' : 'null';
}

for my $stuff ([], undef) {
  $body   = {exists => 1, value => {stuff => $stuff, id => 42, name => undef}};
  @errors = $schema->validate_response([get => '/nullable-data'], {body => \&body});
  is "@errors", "", sprintf 'stuff %s', $stuff ? 'array' : 'null';
}

$schema = JSON::Validator->new->schema('data://main/issue-241.json')->schema;
$body   = {exists => 1, value => {name => undef}};
@errors = $schema->validate_response([get => '/test'], {body => \&body});
is "@errors", "", "nullable inside oneOf";

done_testing;

sub body {$body}

__DATA__
@@ spec.json
{
  "openapi": "3.0.0",
  "info": { "title": "Nullable", "version": "" },
  "paths": {
    "/nullable-data": {
      "get": {
        "responses": {
          "200": {
            "content": { "application/json": { "schema": {"$ref": "#/components/schemas/WithNullable"} } }
          }
        }
      }
    },
    "/nullable-ref": {
      "get": {
        "operationId": "withNullableRef",
        "responses": {
          "200": {
            "content": { "application/json": { "schema": {"$ref": "#/components/schemas/WithNullableRef"} } }
          }
        }
      }
    }
  },
  "components": {
    "schemas": {
      "WithNullable": {
        "required": [ "id", "name" ],
        "properties": {
          "extra": { "type": "object", "nullable": true },
          "id": { "type": "integer", "format": "int64" },
          "name": { "type": "string", "nullable": true },
          "stuff": { "type": "array", "nullable": true }
        }
      },
      "WithNullableRef": {
        "required": [ "id", "name" ],
        "properties": {
          "id": { "type": "integer", "format": "int64" },
          "name": { "$ref": "#/components/schemas/WithNullable/properties/name" }
        }
      }
    }
  }
}
@@ issue-241.json
{
  "openapi": "3.0.0",
  "info": { "title": "Nullable", "version": "" },
  "paths": {
    "/test": {
      "get": {
        "responses": {
          "200": {
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "name": {
                      "oneOf": [
                        { "$ref": "#/components/schemas/name1" },
                        { "$ref": "#/components/schemas/name2" }
                      ]
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  },
  "components": {
    "schemas": {
      "name1": { "type": "string", "nullable": "true" },
      "name2": { "type": "integer" } }
  }
}
