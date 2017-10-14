use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use JSON::Validator;

my ($base_url, $jv, $t, @e);

use Mojolicious::Lite;
get '/invalid-fragment'     => 'invalid-fragment';
get '/invalid-relative'     => 'invalid-relative';
get '/relative-to-the-root' => 'relative-to-the-root';

#hook after_render => sub {
#  my ($c, $output, $format) = @_;
#  return unless $base_url;
#  $$output =~ s!http\W+example\.com/*!$base_url!;
#};

$t = Test::Mojo->new;
$jv = JSON::Validator->new(ua => $t->ua);
$t->get_ok('/relative-to-the-root.json')->status_is(200);

$base_url = $t->tx->req->url->to_abs->path('/');
like $base_url, qr{^http}, 'got base_url to web server';

eval { $jv->load_and_validate_schema("${base_url}relative-to-the-root.json") };
ok !$@, "${base_url}relative-to-the-root.json" or diag $@;

my $schema = $jv->schema;
is $schema->get('/id'), 'http://example.com/relative-to-the-root.json', 'get /id';
is $schema->get('/definitions/A/id'),               '#a',     'id /definitions/A/id';
is $schema->get('/definitions/B/id'),               'b.json', 'id /definitions/B/id';
is $schema->get('/definitions/B/definitions/X/id'), '#bx',    'id /definitions/B/definitions/X/id';
is $schema->get('/definitions/B/definitions/Y/id'), 't/inner.json',
  'id /definitions/B/definitions/Y/id';
is $schema->get('/definitions/C/definitions/X/id'),
  'urn:uuid:ee564b8a-7a87-4125-8c96-e9f123d6766f', 'id /definitions/C/definitions/X/id';
is $schema->get('/definitions/C/definitions/Y/id'), '#cy', 'id /definitions/C/definitions/Y/id';

my $ref = $schema->get('/definitions/R1');
is $ref->ref, 'b.json#bx', 'R1 ref';
is $ref->fqn, 'http://example.com/b.json#bx', 'R1 fqn';

{
  local $TODO = 'Check that the root URL of a document does not contain fragment';
  eval { $jv->load_and_validate_schema("${base_url}invalid-fragment.json") };
  like $@, qr{Cannot have fragment}, 'Root ID cannot have a fragment' or diag $@;
}

eval { $jv->load_and_validate_schema("${base_url}invalid-relative.json") };
like $@, qr{Does not match uri}, 'Root ID cannot be relative' or diag $@;

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
