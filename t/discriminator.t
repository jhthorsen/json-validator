use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use lib '.';
use t::Api;

use Mojolicious::Lite;
plugin Swagger2 => {url => 'data://main/discriminator.json'};

my $t = Test::Mojo->new;
$t::Api::RES = {};

my %cat = (name => 'kit-e-cat', petType => 'Cat', huntingSkill => "adventurous");
my %dog = (name => 'dog-e-dog', petType => 'Dog', packSize     => 4);

# jhthorsen: The error message is not very good.
# I think this must be fixed in JSON::Validator.
# {"errors":[{"message":"allOf failed: Missing property.","path":"\/body"}]}

$t->post_ok('/api/pets' => json => {%cat, petType => 'Dog'})->status_is(400)
  ->json_like('/errors/0/message', qr{Missing property});
$t->post_ok('/api/pets' => json => {%cat})->status_is(200);
$t->post_ok('/api/pets' => json => {%dog, petType => 'Cat'})->status_is(400)
  ->json_like('/errors/0/message', qr{Missing property});
$t->post_ok('/api/pets' => json => {%dog})->status_is(200);
$t->post_ok('/api/pets' => json => {%dog, petType => ''})->status_is(400)
  ->json_is('/errors/0/message', 'Discriminator petType has no value.');
$t->post_ok('/api/pets' => json => {%dog, petType => 'Hamster'})->status_is(400)
  ->json_is('/errors/0/message', 'No definition for discriminator Hamster.');

done_testing;

__DATA__
@@ discriminator.json
{
  "swagger" : "2.0",
  "info" : { "version": "0.8", "title" : "Test API for body parameters" },
  "consumes" : [ "application/json" ],
  "produces" : [ "application/json" ],
  "schemes" : [ "http" ],
  "basePath" : "/api",
  "paths" : {
    "/pets" : {
      "post" : {
        "x-mojo-controller": "t::Api",
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
