use Mojo::Base -strict;
use JSON::Validator;
use Test::More;

my $schema = JSON::Validator->new->schema('data://main/spec.json')->schema;
my ($form, @errors);

for my $image (undef, '') {
  $form   = {image => '', id => 'i1'};
  @errors = $schema->validate_request([post => '/pets'], {formData => $form});
  is "@errors", '/image: Missing property.', 'missing image';
}

$form   = {image => '0', id => 'i1'};
@errors = $schema->validate_request([post => '/pets'], {formData => $form});
is "@errors", '', 'valid input';

done_testing;

__DATA__
@@ spec.json
{
  "swagger": "2.0",
  "info": {"version": "0.8", "title": "Test body"},
  "basePath": "/api",
  "paths": {
    "/pets": {
      "post": {
        "parameters": [
          {"name": "image", "in": "formData", "type": "file", "required": true},
          {"name": "id", "in": "formData", "type": "string"}
        ],
        "responses": {
          "200": {"description": "ok", "schema": {"type": "object"}}
        }
      }
    }
  }
}
