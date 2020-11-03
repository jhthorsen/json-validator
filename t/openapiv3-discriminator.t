use Mojo::Base -strict;
use JSON::Validator;
use Test::More;

my $schema = JSON::Validator->new->schema('data://main/spec.json')->schema;
my ($body, @errors);

my %cat = (name => 'kit-e-cat', petType => 'cat', huntingSkill => 'adventurous');
my %dog = (name => 'dog-e-dog', petType => 'dog', packSize     => 4);

$body   = sub { {exists => 1, value => {%cat, petType => 'dog'}} };
@errors = $schema->validate_request([post => '/pets'], {body => $body});
is "@errors", '/body/packSize: /allOf/1 Missing property.', 'invalid dog';

$body   = sub { {exists => 1, value => {%cat}} };
@errors = $schema->validate_request([post => '/pets'], {body => $body});
is "@errors", '', 'valid cat';

$body   = sub { {exists => 1, value => {%dog, petType => 'cat'}} };
@errors = $schema->validate_request([post => '/pets'], {body => $body});
is "@errors", '/body/huntingSkill: /allOf/1 Missing property.', 'invalid cat';

$body   = sub { {exists => 1, value => {%dog}} };
@errors = $schema->validate_request([post => '/pets'], {body => $body});
is "@errors", '', 'valid dog';

$body   = sub { {exists => 1, value => {%dog, petType => ''}} };
@errors = $schema->validate_request([post => '/pets'], {body => $body});
is "@errors", '/body: Discriminator petType has no value.', 'discriminator is required';

$body   = sub { {exists => 1, value => {%cat, petType => 'Hamster'}} };
@errors = $schema->validate_request([post => '/pets'], {body => $body});
is "@errors", '/body: No definition for discriminator Hamster.', 'invalid discriminator';

done_testing;

__DATA__
@@ spec.json
{
  "openapi": "3.0.0",
  "info": { "title": "Discriminator", "version": "" },
  "paths": {
    "/pets": {
      "post": {
        "requestBody": {
          "content": { "application/json": { "schema": { "$ref": "#/components/schemas/Pet" } } }
        }
      }
    }
  },
  "components": {
    "schemas": {
      "Pet": {
        "type": "object",
        "discriminator": {
          "propertyName": "petType",
          "mapping": {
            "cat": "#/components/schemas/Cat",
            "dog": "#/components/schemas/Dog"
          }
        },
        "required": ["name", "petType"],
        "properties": {
          "name": {"type": "string"},
          "petType": {"type": "string"}
        }
      },
      "Cat": {
        "description": "A representation of a cat",
        "allOf": [
          {"$ref": "#/components/schemas/Pet"},
          {
            "type": "object",
            "required": ["huntingSkill"],
            "properties": {"huntingSkill": {"type": "string", "description": "The measured skill for hunting", "default": "lazy", "enum": ["clueless", "lazy", "adventurous", "aggressive"]}
            }
          }
        ]
      },
      "Dog": {
        "description": "A representation of a dog",
        "allOf": [
          {"$ref": "#/components/schemas/Pet"},
          {
            "type": "object",
            "required": ["packSize"],
            "properties": {
              "packSize": {"type": "integer", "format": "int32", "description": "the size of the pack the dog is from", "default": 0, "minimum": 0}
            }
          }
        ]
      }
    }
  }
}
