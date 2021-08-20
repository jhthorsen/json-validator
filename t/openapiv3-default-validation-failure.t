use Mojo::Base -strict;
use JSON::Validator;
use Test::More;

subtest 'with coerce defaults' => sub {
  my $schema = JSON::Validator->new->schema('data://main/spec.json')->schema;

  $schema->coerce('defaults');

  my @errors = @{ $schema->errors };

  ok( @errors == 0, 'No schema errors' ) or diag "Errors: ", join("\n", @errors), "\n";
};

subtest 'without coerce defaults' => sub {
  my $schema = JSON::Validator->new->schema('data://main/spec.json')->schema;

  my @errors = @{ $schema->errors };

  ok( @errors == 0, 'No schema errors' ) or diag "Errors: ", join("\n", @errors), "\n";
};

done_testing;

__DATA__
@@ spec.json
{
  "openapi": "3.0.0",
  "info": { "title": "Schema Errors Bug", "version": "0.0.1" },
  "paths": {
    "/pets": {
      "get": {
        "parameters": [
          {
            "description": "Get pets",
            "in": "query",
            "name": "page",
            "schema": { "type": "integer" }
          }
        ],
        "responses" : {
          "200": {
            "description": "pet response"
          }
        }
      }
    }
  }
}
