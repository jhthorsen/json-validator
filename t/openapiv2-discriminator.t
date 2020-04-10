use lib '.';
use Mojo::Base -strict;
use t::OpenApiApp;
use JSON::Validator::Schema::OpenAPIv2;
use Test::More;
use Test::Mojo;

my $app = t::OpenApiApp->new->schema(
  JSON::Validator::Schema::OpenAPIv2->new->data('data://main/spec.json'));

my $t   = Test::Mojo->new($app);
my %cat = (name => 'Goma', petType => 'Cat', huntingSkill => 'adventurous');
my %dog = (name => 'Snoop', petType => 'Dog', packSize => 4);

$t->post_ok('/pets' => json => {%cat, petType => 'Dog'})->status_is(200)
  ->json_is('/req', undef)
  ->json_is('/req_errors',
  [{path => '/body/packSize', message => '/allOf/1 Missing property.'}]);

$t->post_ok('/pets' => json => {%cat})->status_is(200)
  ->json_is('/req/0/value/name', 'Goma')->json_is('/req_errors', []);

$t->post_ok('/pets' => json => {%dog, petType => 'Cat'})->status_is(200)
  ->json_is('/req', undef)
  ->json_is('/req_errors',
  [{path => '/body/huntingSkill', message => '/allOf/1 Missing property.'}]);

$t->post_ok('/pets' => json => {%dog})->status_is(200)
  ->json_is('/req/0/value/name', 'Snoop')->json_is('/req_errors', []);

$t->post_ok('/pets' => json => {%dog, petType => ''})->status_is(200)
  ->json_is('/req', undef)
  ->json_is('/req_errors',
  [{path => '/body', message => 'Discriminator petType has no value.'}]);

$t->post_ok('/pets' => json => {%dog, petType => 'Hamster'})->status_is(200)
  ->json_is('/req', undef)
  ->json_is('/req_errors',
  [{path => '/body', message => 'No definition for discriminator Hamster.'}]);

done_testing;

__DATA__
@@ spec.json
{
  "swagger" : "2.0",
  "info" : { "version": "0.8", "title" : "Test discriminator" },
  "consumes" : [ "application/json" ],
  "produces" : [ "application/json" ],
  "schemes" : [ "http" ],
  "basePath" : "/api",
  "paths" : {
    "/pets" : {
      "post" : {
        "operationId" : "addPet",
        "parameters" : [
          { "in": "body", "name": "body", "schema": { "$ref" : "#/definitions/Pet" } }
        ],
        "responses" : {
          "200": {
            "description": "pet response",
            "schema": { "type": "object" }
          }
        }
      }
    }
  },
  "definitions": {
    "Pet": {
      "type": "object",
      "discriminator": "petType",
      "required": [ "name", "petType" ],
      "properties": {
        "name": { "type": "string" },
        "petType": { "type": "string" }
      }
    },
    "Cat": {
      "description": "A representation of a cat",
      "allOf": [
        { "$ref": "#/definitions/Pet" },
        {
          "type": "object",
          "required": [ "huntingSkill" ],
          "properties": {
            "huntingSkill": {
              "type": "string",
              "description": "The measured skill for hunting",
              "default": "lazy",
              "enum": [ "clueless", "lazy", "adventurous", "aggressive" ]
            }
          }
        }
      ]
    },
    "Dog": {
      "description": "A representation of a dog",
      "allOf": [
        { "$ref": "#/definitions/Pet" },
        {
          "type": "object",
          "required": [ "packSize" ],
          "properties": {
            "packSize": {
              "type": "integer",
              "format": "int32",
              "description": "the size of the pack the dog is from",
              "default": 0,
              "minimum": 0
            }
          }
        }
      ]
    }
  }
}
