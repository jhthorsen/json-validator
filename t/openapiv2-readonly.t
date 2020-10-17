use Mojo::Base -strict;
use JSON::Validator;
use Test::More;

my $schema = JSON::Validator->new->schema('data://main/spec.json')->schema;
my ($body, @errors);

$body   = sub { +{exists => 1, value => {}} };
@errors = $schema->validate_request([post => '/user'], {body => $body});
is "@errors", '', 'required is ignored on validate_request';

@errors = $schema->validate_response([post => '/user'], {body => $body});
is "@errors", '/body/age: Missing property.', 'age is required in response';

$body   = sub { +{exists => 1, value => {age => 42}} };
@errors = $schema->validate_request([post => '/user'], {body => $body});
is "@errors", '/body/age: Read-only.', 'age is read-only for request';

@errors = $schema->validate_response([post => '/user'], {body => $body});
is "@errors", '', 'age is present in response';

done_testing;

__DATA__
@@ spec.json
{
  "swagger": "2.0",
  "info": {"version": "", "title": "Test readonly"},
  "basePath": "/api",
  "paths": {
    "/user": {
      "post": {
        "parameters": [
          {"name":"body", "in":"body", "schema": { "$ref": "#/definitions/User" }}
        ],
        "responses": {
          "200": { "description": "ok", "schema": { "$ref": "#/definitions/User" } }
        }
      }
    }
  },
  "definitions": {
    "User": {
      "type": "object",
      "required": ["age"],
      "properties": {
        "age": {"type": "integer", "readOnly": true}
      }
    }
  }
}
