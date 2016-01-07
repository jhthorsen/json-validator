use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

#
# This test used to fail with error messages such as:
#   /paths/~1commands/get/responses/default: Expected only one to match.
#   /info/title: Missing property.
#   /definitions/Error/properties/errors/items: [0] Properties not allowed: message, path. [1] Expected array - got object.
# The message that tripped me off was "Expected only one to match." which
# made me believe there was a bug in JSON::Validator. The real reason was
# however that spec.json contained an invalid spec. Such as "required":true,
# instead of "required":["message"].
# I think it would be nice to have better error messages, but at right now I
# don't have the capacity to figure out how to make those.
#
# - Jan Henning Thorsen
#

plan skip_all => 'Swagger2 0.66+ is required' unless eval 'require Swagger2;Swagger2->VERSION >= 0.66';
my $swagger = Swagger2->new('data://main/spec.json');
my @errors  = $swagger->validate;
ok !@errors, 'no errors in spec.json' or diag join "\n", @errors;
done_testing;

__DATA__
@@ spec.json
{
  "swagger": "2.0",
  "info": {
    "title": "(part of) Convos API specification",
    "version": "0.87"
  },
  "host": "demo.convos.by",
  "basePath": "/1.0",
  "schemes": [ "http" ],
  "paths": {
    "/commands": {
      "get": {
        "responses": {
          "200": {
            "description": "List of commands.",
            "schema": {
              "type": "object",
              "properties": {
                "commands": { "type": "array", "$ref": "#/definitions/Command" }
              }
            }
          },
          "default": {
            "description": "Error.",
            "schema": { "$ref": "#/definitions/Error" }
          }
        }
      }
    }
  },
  "definitions": {
    "Command": {
      "required": ["id", "command"],
      "properties": {
        "id": { "type": "string",  "description": "jhthorsen: Cannot remember what 'id' is." },
        "command": { "type": "string",  "description": "A command to be sent to backend" }
      }
    },
    "Error": {
      "properties": {
        "errors": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["message"],
            "properties": {
              "message": { "type": "string", "description": "Human readable description of the error" },
              "path": { "type": "string", "description": "JSON pointer to the input data where the error occur" }
            }
          }
        }
      }
    }
  }
}
