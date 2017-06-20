use Mojo::Base -strict;
use Test::More;
use JSON::Validator 'validate_json';
use JSON::Validator::OpenAPI;

my $data = {};
$data->{rec} = $data;

$SIG{ALRM} = sub { die 'Recursion!' };
alarm 2;
my @errors = ('i_will_be_removed');
eval { @errors = validate_json {top => $data}, 'data://main/spec.json' };
is $@, '', 'no error';
is_deeply(\@errors, [], 'avoided recursion');

# this part of the test checks that we don't go into an infite loop
my $validator = JSON::Validator::OpenAPI->new;
is $validator->load_and_validate_spec('data://main/user.json'), $validator,
  'load_and_validate_spec no recursion';
is $validator->schema($validator->schema->data), $validator,
  'schema() handles $schema with recursion';

done_testing;
__DATA__
@@ spec.json
{
  "properties": {
    "top": { "$ref": "#/definitions/again" }
  },
  "definitions": {
    "again": {
      "anyOf": [
        {"type": "string"},
        {
          "type": "object",
          "properties": {
            "rec": {"$ref": "#/definitions/again"}
          }
        }
      ]
    }
  }
}
@@ user.json
{
  "swagger" : "2.0",
  "info" : { "version": "0.8", "title" : "User schema" },
  "schemes" : [ "http" ],
  "basePath" : "/api",
  "paths" : {
    "/user" : {
      "post" : {
        "operationId" : "User",
        "parameters": [{
          "name": "data",
          "in": "body",
          "required": true,
          "schema": {
            "$ref": "#/definitions/user"
            }
        }],
        "responses" : {
          "200": { "description": "response", "schema": { "type": "object" } }
        }
      }
    }
  },
  "definitions": {
    "user": {
      "type": "object",
      "properties": {
        "name": {
          "type": "string"
        },
        "siblings": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/user"
          }
        }
      }
    }
  }
}
