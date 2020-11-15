use Mojo::Base -strict;
use JSON::Validator::Schema::OpenAPIv2;
use Test::Deep;
use Test::More;

my $schema = JSON::Validator::Schema::OpenAPIv2->new;
my $errors;

$errors = $schema->data('data://main/schema.json')->errors;
like "@$errors", qr{Properties not allowed}, 'invalid schema';

$errors = $schema->allow_invalid_ref(1)->errors;
is "@$errors", '', 'allow_invalid_ref after loading schema';

$errors = $schema->allow_invalid_ref(1)->data('data://main/schema.json')->errors;
is "@$errors", '', 'allow_invalid_ref before loading schema';

done_testing;

__DATA__
@@ schema.json
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
