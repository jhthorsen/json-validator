use Mojo::Base -strict;
use JSON::Validator;
use Mojo::Headers;
use Test::More;

my $schema  = JSON::Validator->new->schema('data://main/spec.json')->schema;
my $headers = Mojo::Headers->new;
my $body    = sub { +{exists => 1, value => {}} };
my @errors;

$headers->header('X-Number' => 'x')->header('X-String' => '123');
@errors = $schema->validate_request([get => '/test'], {header => $headers->to_hash(1)});
is "@errors", '/X-Number: Expected number - got string.', 'request header not a number';

$headers->header('X-Number' => '42');
@errors = $schema->validate_request([get => '/test'], {header => $headers->to_hash(1)});
is "@errors", '', 'request header is number';

$headers->header('X-Array' => '42');
@errors = $schema->validate_request([get => '/test'], {header => $headers->to_hash});
is ref $headers->to_hash->{'X-Array'}, '', 'request header is not an array';
is "@errors", '', 'request header is coerced into an array';

@errors = $schema->validate_response([get => '/test'], {body => $body, header => $headers->to_hash});
is "@errors", '', 'response header is coerced into an array';

$headers->add('X-Array' => '3.14');
@errors = $schema->validate_request([get => '/test'], {header => $headers->to_hash(1)});
is ref $headers->to_hash(1)->{'X-Array'}, 'ARRAY', 'header is an array';
is "@errors", '', 'request header as array is valid';

$headers->header('X-Bool' => '42');
@errors = $schema->validate_request([get => '/test'], {header => $headers->to_hash(1)});
is "@errors", '/X-Bool: Expected boolean - got string.', 'request header not a boolean';

@errors = $schema->validate_response([get => '/test'], {body => $body, header => $headers->to_hash(1)});
is "@errors", '/X-Bool: Expected boolean - got string.', 'response header not a boolean';

for my $str (qw(true false 1 0)) {
  $headers->header('X-Bool' => $str);
  @errors = $schema->validate_request([get => '/test'], {header => $headers->to_hash});
  is "@errors", '', q(request header as boolean "$str");

  @errors = $schema->validate_response([get => '/test'], {body => $body, header => $headers->to_hash(1)});
  is "@errors", '', q(response header as boolean "$str");
}

done_testing;

__DATA__
@@ spec.json
{
  "swagger": "2.0",
  "info": {"version": "", "title": "Test headers"},
  "basePath": "/api",
  "paths": {
    "/test": {
      "get": {
        "parameters": [
          {"in": "header", "name": "X-Bool", "type": "boolean", "description": "desc..."},
          {"in": "header", "name": "X-Number", "type": "number", "description": "desc..."},
          {"in": "header", "name": "X-String", "type": "string", "description": "desc..."},
          {"in": "header", "name": "X-Array", "items": {"type": "string"}, "type": "array", "description": "desc..."}
        ],
        "responses": {
          "200": {
            "description": "this is required",
            "headers": {
              "X-Array": {"type": "array", "items": {"type": "string"}, "minItems": 1},
              "X-Bool": {"type": "boolean"}
            },
            "schema": {"type": "object"}
          }
        }
      }
    }
  }
}
