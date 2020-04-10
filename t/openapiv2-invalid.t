use lib '.';
use t::Helper;
use JSON::Validator::Schema::OpenAPIv2;
use Test::More;

my $schema = JSON::Validator::Schema::OpenAPIv2->new;

$schema->data('data://main/invalid-parameters.json');
is_deeply $schema->errors,
  [E('/paths/~1pets/post/parameters', 'Unique items required.')],
  'duplicate body';

$schema->data('data://main/invalid-ref.json');
is_deeply $schema->errors,
  [E('/paths/~1pets/post', 'Properties not allowed: $ref.')],
  'allow_invalid_ref 0';
is_deeply [keys %{$schema->data->{paths}{'/pets'}{post}}], ['$ref'],
  'unbundled schema';

$schema->allow_invalid_ref(1)->data('data://main/invalid-ref.json');
is_deeply $schema->errors, [], 'allow_invalid_ref 1';
is_deeply [keys %{$schema->data->{paths}{'/pets'}{post}}], ['responses'],
  'bundled schema';

done_testing;

__DATA__
@@ invalid-parameters.json
{
  "swagger": "2.0",
  "info": { "version": "1.0.0", "title": "Invalid schema" },
  "paths": {
    "/pets": {
      "post": {
        "parameters": [
          { "in": "body", "name": "body", "required": true, "schema": {} },
          { "in": "body", "name": "body", "required": true, "schema": {} }
        ],
        "responses": {
          "200": {
            "description": "An paged array of pets",
            "schema": {}
          }
        }
      }
    }
  }
}
@@ invalid-ref.json
{
  "swagger": "2.0",
  "info": { "version": "1.0.0", "title": "Invalid schema" },
  "paths": {
    "/pets": {
      "post": { "$ref": "#/x-ref/postPets" }
    }
  },
  "x-ref": {
    "postPets": {
      "responses": {
        "200": {
          "description": "An paged array of pets",
          "schema": { "$ref": "#/definitions/Pet" }
        }
      }
    }
  },
  "definitions": {
    "Pet": {
    }
  }
}
