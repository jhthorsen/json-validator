use Mojo::Base -strict;
use Mojo::Util 'dumper';
use JSON::Validator::OpenAPI;
use Test::More;

my $jv = JSON::Validator::OpenAPI->new(resolver => sub { });
my $jv_resolver = JSON::Validator::OpenAPI->new;
my $api_spec = $jv->schema('data://main/swagger2/issues/89.json')->schema;
my @errors = $jv_resolver->schema(JSON::Validator::OpenAPI::SPECIFICATION_URL())->validate($api_spec->data);

local $TODO = 'https://github.com/jhthorsen/swagger2/issues/89';
diag dumper($api_spec->data) if $ENV{JSON_VALIDATOR_DEBUG};
diag dumper(\@errors) if $ENV{HARNESS_IS_VERBOSE};
is @errors, 2, 'invalid spec';

done_testing;

__DATA__
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
