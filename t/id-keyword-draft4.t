use Mojo::Base -strict;
use Mojo::JSON 'encode_json';
use Test::Mojo;
use Test::More;
use JSON::Validator;

my ($base_url, $jv, $t, @e);

use Mojolicious::Lite;
get '/invalid-fragment'     => 'invalid-fragment';
get '/invalid-relative'     => 'invalid-relative';
get '/relative-to-the-root' => 'relative-to-the-root';

$t = Test::Mojo->new;
$jv = JSON::Validator->new(ua => $t->ua);
$t->get_ok('/relative-to-the-root.json')->status_is(200);

$base_url = $t->tx->req->url->to_abs->path('/');
like $base_url, qr{^http}, 'got base_url to web server';
is $jv->version, 4,    'default version';
is $jv->_id_key, 'id', 'default id_key';

delete $jv->{version};
eval { $jv->load_and_validate_schema("${base_url}relative-to-the-root.json") };
ok !$@, "${base_url}relative-to-the-root.json" or diag $@;
is $jv->{version}, 4, 'detected version from draft-04';

my $schema = $jv->schema;
is $schema->get('/id'), 'http://example.com/relative-to-the-root.json',
  'get /id';
is $schema->get('/definitions/B/id'), 'b.json', 'id /definitions/B/id';
is $schema->get('/definitions/B/definitions/X/id'), '#bx',
  'id /definitions/B/definitions/X/id';
is $schema->get('/definitions/B/definitions/Y/id'), 't/inner.json',
  'id /definitions/B/definitions/Y/id';
is $schema->get('/definitions/C/definitions/X/id'),
  'urn:uuid:ee564b8a-7a87-4125-8c96-e9f123d6766f',
  'id /definitions/C/definitions/X/id';
is $schema->get('/definitions/C/definitions/Y/id'), '#cy',
  'id /definitions/C/definitions/Y/id';

my $ref = $schema->get('/definitions/R1');
ok $ref->{$_}, "got $_" for qw($ref %%fqn %%schema);
is encode_json($ref), '{"$ref":"b.json#bx"}', 'ref encode_json';
$ref = tied %$ref;
is $ref->ref, 'b.json#bx', 'ref ref';
is $ref->fqn, 'http://example.com/b.json#bx', 'ref fqn';
ok $ref->schema->{definitions}{Y}, 'ref schema';

eval { $jv->load_and_validate_schema("${base_url}invalid-fragment.json") };
like $@, qr{cannot have a fragment}, 'Root id cannot have a fragment'
  or diag $@;

eval { $jv->load_and_validate_schema("${base_url}invalid-relative.json") };
like $@, qr{cannot have a relative}, 'Root id cannot be relative' or diag $@;

done_testing;

__DATA__
@@ invalid-fragment.json.ep
{"id": "http://example.com/invalid-fragment.json#cannot_be_here"}
@@ invalid-relative.json.ep
{"id": "whatever"}
@@ relative-to-the-root.json.ep
{
  "id": "http://example.com/relative-to-the-root.json",
  "definitions": {
    "A": { "id": "#a" },
    "B": {
      "id": "b.json",
      "definitions": {
        "X": { "id": "#bx" },
        "Y": { "id": "t/inner.json" }
      }
    },
    "C": {
      "id": "c.json",
      "definitions": {
        "X": { "id": "urn:uuid:ee564b8a-7a87-4125-8c96-e9f123d6766f" },
        "Y": { "id": "#cy" }
      }
    },
    "R1": { "$ref": "b.json#bx" },
    "R2": { "$ref": "#a" },
    "R3": { "$ref": "urn:uuid:ee564b8a-7a87-4125-8c96-e9f123d6766f" }
  }
}
