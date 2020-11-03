use Mojo::Base -strict;
use JSON::Validator;
use Test::More;

my $schema = JSON::Validator->new->schema('data://main/spec.json')->schema;
my ($body, @errors);

$body   = sub { +{exists => 1, value => {birth => '1983-02-24'}} };
@errors = $schema->validate_request([post => '/user'], {body => $body});
is "@errors", '', 'required is ignored on validate_request';

$body   = sub { +{exists => 1, value => {age => 42, birth => '1983-02-24'}} };
@errors = $schema->validate_request([post => '/user'], {body => $body});
is "@errors", '/body/age: Read-only.', 'age is read-only for request';

$body   = sub { +{exists => 1, value => {}} };
@errors = $schema->validate_response([get => '/user'], {body => $body});
is "@errors", '/body/age: Missing property.', 'age is required in response';

$body   = sub { +{exists => 1, value => {age => 42}} };
@errors = $schema->validate_response([get => '/user'], {body => $body});
is "@errors", '', 'age is present in response';

$body   = sub { +{exists => 1, value => {age => 42, birth => '1983-02-24'}} };
@errors = $schema->validate_response([get => '/user'], {body => $body});
is "@errors", '/body/birth: Write-only.', 'birth is write-only in response';

done_testing;

__DATA__
@@ spec.json
{
  "openapi": "3.0.0",
  "info": { "title": "Read/write-only", "version": "" },
  "paths": {
    "/user": {
      "get": {
        "responses": {
          "200": {
            "content": { "application/json": { "schema": { "$ref": "#/components/schemas/User" } } }
          }
        }
      },
      "post": {
        "requestBody": {
          "required": true,
          "content": { "application/json": { "schema": { "$ref": "#/components/schemas/User" } } }
        }
      }
    }
  },
  "components": {
    "schemas": {
      "User": {
        "type": "object",
        "required": ["age", "birth"],
        "properties": {
          "age": {"type": "integer", "readOnly": true},
          "birth": {"type": "string", "writeOnly": true}
        }
      }
    }
  }
}
