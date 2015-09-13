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

$t->post_ok('/', json => {})->status_is(400)->content_like(qr{/name});
$t->post_ok('/', json => {name => "foo"})->status_is(200);

done_testing;
__DATA__
@@ spec.json
{
  "type": "object",
  "properties": { "name": { "type": "string" } },
  "required": ["name"]
}
