use Mojo::Base -strict;
use Test::More;
use Mojo::JSON;
use JSON::Validator;

my $jv = JSON::Validator->new->schema('data://main/spec.json');
my @errors
  = $jv->validate({prop1 => Mojo::JSON->false, prop2 => Mojo::JSON->false});

is "@errors", "";

done_testing;

__DATA__

@@ spec.json
{
  "type": "object",
  "properties": {
    "prop1": {
      "$ref": "data://main/defs.json#/definitions/item"
    },
    "prop2": {
      "$ref": "data://main/defs.json#/definitions/item"
    }
  }
}

@@ defs.json
{
  "definitions": {
    "item": {
      "oneOf": [
        {"type": "object"},
        {"type": "boolean"}
      ]
    }
  }
}
