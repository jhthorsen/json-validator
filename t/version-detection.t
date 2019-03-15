use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use JSON::Validator;

use Mojolicious::Lite;
get '/person' => 'person';

my $t = Test::Mojo->new;
$t->get_ok('/person.json')->status_is(200);
my $base_url = $t->tx->req->url->to_abs->path('/');
my $document = $t->tx->res->json;

{
  my $jv = JSON::Validator->new;

  eval { $jv->load_and_validate_schema($document); };
  ok !$@, 'local schema.json' or diag $@;

  is $jv->version, 7,     'detected version from local document, as draft-07';
  is $jv->_id_key, '$id', 'detected id_key from local document, as draft-07';
}

{
  my $jv = JSON::Validator->new(ua => $t->ua);

  eval { $jv->load_and_validate_schema("${base_url}person.json"); };
  ok !$@, "${base_url}schema.json" or diag $@;

  is $jv->version, 7,     'detected version from document via url, as draft-07';
  is $jv->_id_key, '$id', 'detected id_key from document via url, as draft-07';
}

done_testing;

__DATA__
@@ invalid-relative.json.ep
{"$id": "whatever"}
@@ person.json.ep
{
  "$schema":"http://json-schema.org/draft-07/schema",
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
