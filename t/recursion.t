use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use JSON::Validator;

plan skip_all => 'TEST_ACCEPTANCE=1' unless $ENV{TEST_ACCEPTANCE};

my $data = {};
$data->{rec} = $data;

eval { JSON::Validator->new->schema('data://main/spec.json')->validate({top => $data}) };
like $@, qr{recursive data structures};

done_testing;
__DATA__
@@ spec.json
{
  "properties": {
    "top": { "$ref": "#/definitions/again" }
  },
  "definitions": {
    "again": {
      "anyOf": [
        {"type": "string"},
        {
          "type": "object",
          "properties": {
            "rec": {"$ref": "#/definitions/again"}
          }
        }
      ]
    }
  }
}
