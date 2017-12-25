use Mojo::Base -strict;
use Test::More;
use JSON::Validator::OpenAPI;

my $validator = JSON::Validator::OpenAPI->new;

is $validator->load_and_validate_schema('data://main/echo.json'), $validator,
  'load_and_validate_schema no options';
is $validator->schema->get('/info/version'), '42.0', 'version';

eval { $validator->load_and_validate_schema('data://main/swagger2/issues/89.json') };
like $@, qr{/definitions/\$ref}si, 'ref in the wrong place';

eval {
  $validator->load_and_validate_schema('data://main/swagger2/issues/89.json',
    {allow_invalid_ref => 1, version_from_class => 'JSON::Validator'});
  is $validator->schema->get('/info/version'), JSON::Validator->VERSION, 'version_from_class';
  is_deeply $validator->schema->get('/definitions/foo/properties'), {}, 'allow_invalid_ref';
} or diag $@;

done_testing;

__DATA__
@@ echo.json
{
  "swagger" : "2.0",
  "info" : { "version": "42.0", "title" : "Pets" },
  "schemes" : [ "http" ],
  "basePath" : "/api",
  "paths" : {
    "/echo" : {
      "post" : {
        "x-mojo-name" : "echo",
        "parameters" : [
          { "in": "body", "name": "body", "schema": { "type" : "object" } }
        ],
        "responses" : {
          "200": { "description": "Echo response", "schema": { "type": "object" } },
          "400": { "description": "Echo response", "schema": { "type": "object" } }
        }
      }
    }
  }
}
@@ swagger2/issues/89.json
{
  "swagger" : "2.0",
  "info" : { "version": "0.8", "title" : "Test auto response" },
  "paths" : { "$ref": "#/x-def/paths" },
  "definitions": { "$ref": "#/x-def/defs" },
  "x-def": {
    "defs": {
      "foo": { "properties": {} }
    },
    "paths": {
      "/auto" : {
        "post" : {
          "responses" : {
            "200": { "description": "response", "schema": { "type": "object" } }
          }
        }
      }
    }
  }
}
