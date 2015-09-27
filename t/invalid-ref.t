use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new;

eval { $validator->schema('data://main/spec.json') };
like $@, qr{Could not find "\#/definitions/Pet"}, 'missing definition';

done_testing;

__DATA__
@@ spec.json
{
  "schema": {
    "type": "array",
    "items": { "$ref": "#/definitions/Pet" }
  }
}
