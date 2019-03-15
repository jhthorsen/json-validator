use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use JSON::Validator;

use Mojolicious::Lite;
get '/person'           => 'person';
get '/invalid-relative' => 'invalid-relative';

my $t  = Test::Mojo->new;
my $jv = JSON::Validator->new(ua => $t->ua);

$t->get_ok('/person.json')->status_is(200);
my $base_url = $t->tx->req->url->to_abs->path('/');
eval {
  $jv->load_and_validate_schema("${base_url}person.json",
    {schema => 'http://json-schema.org/draft-06/schema'});
};
ok !$@, "${base_url}schema.json" or diag $@;

is $jv->version, 6,    'detected version from $arg, as draft-06';
is $jv->_id_key, 'id', 'detected id_key from $arg, as draft-06';

eval { $jv->load_and_validate_schema("${base_url}invalid-relative.json") };
ok !$@, 'Root id can be relative' or diag $@;

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
