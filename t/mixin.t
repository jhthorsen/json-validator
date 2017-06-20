use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $jv = JSON::Validator->new;
$jv->schema('data://main/spec.json');

is $jv->schema->get('/properties/x'), 111,               'x';
is $jv->schema->get('/properties/y'), 'in conflict',     'y';
is $jv->schema->get('/properties/z'), 'not in conflict', 'z';

done_testing;
__DATA__
@@ spec.json
{
  "properties": {
    "y": "in conflict",
    "z": "not in conflict",
    "$ref": "#/definitions/again"
  },
  "definitions": {
    "again": {
      "x": 111,
      "y": 222
    }
  }
}
