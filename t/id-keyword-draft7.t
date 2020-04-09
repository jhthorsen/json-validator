use Mojo::Base -strict;
use JSON::Validator;
use Test::Mojo;
use Test::More;

my ($base_url, $jv, $t, @e);

use Mojolicious::Lite;
get '/person'           => 'person';
get '/invalid-relative' => 'invalid-relative';

$t  = Test::Mojo->new;
$jv = JSON::Validator->new(ua => $t->ua);

eval {
  $t->get_ok('/person.json')->status_is(200);
  $base_url = $t->tx->req->url->to_abs->path('/');
  $jv->load_and_validate_schema("${base_url}person.json",
    {schema => 'http://json-schema.org/draft-07/schema#'});
};
ok !$@, "${base_url}schema.json" or diag $@;

is $jv->version, 7,     'detected version from draft-07';
is $jv->_id_key, '$id', 'detected id_key from draft-07';

eval { $jv->load_and_validate_schema("${base_url}invalid-relative.json") };
like $@, qr{cannot have a relative}, 'Root id cannot be relative' or diag $@;

done_testing;

__DATA__
@@ invalid-relative.json.ep
{"$id": "whatever"}
@@ person.json.ep
{
  "$id": "http://example.com/person.json",
  "definitions": {
    "Person": {
      "type": "object",
      "properties": {
        "firstName": { "type": "string" }
      }
    }
  }
}
