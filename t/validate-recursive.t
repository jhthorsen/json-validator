use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use JSON::Validator 'validate_json';

{
  use Mojolicious::Lite;
  post '/' => sub {
    my $c = shift;
    my @errors = validate_json $c->req->json, 'data://main/spec.json';
    $c->render(status => @errors ? 400 : 200, text => "@errors");
  };
}

my $t = Test::Mojo->new;

$t->post_ok('/', json => {})->status_is(400)->content_like(qr{/person});
$t->post_ok('/', json => {person => {name => "foo"}})->status_is(200);
$t->post_ok('/', json => {person => {name => "foo", children => [{}]}})->status_is(400)->content_like(qr{/person});

done_testing;
__DATA__
@@ spec.json
{
  "type": "object",
  "properties": {
    "person": {
      "$ref": "#/definitions/person"
    }
  },
  "required": [
    "person"
  ],
  "definitions": {
    "person": {
      "type": "object",
      "properties": {
        "name": {
          "type": "string"
        },
        "children": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/person"
          }
        }
      },
      "required": [
        "name"
      ]
    }
  }
}
