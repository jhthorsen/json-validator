use Mojo::Base -strict;
use Test::More;
use Mojo::JSON;
use JSON::Validator;

my $validator = JSON::Validator->new->schema('data://main/schema.yml');
my @errors = $validator->validate({prop1 => Mojo::JSON->false, prop2 => Mojo::JSON->false});

is "@errors", "";

done_testing;

__DATA__

@@ schema.yml
type: object
properties:
  prop1:
    $ref: "data://main/defs.yml#/definitions/item"
  prop2:
    $ref: "data://main/defs.yml#/definitions/item"

@@ defs.yml
definitions:
  item:
    oneOf:
    - type: object
    - type: boolean
