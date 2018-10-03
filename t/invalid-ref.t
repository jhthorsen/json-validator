use Mojo::Base -strict;
use Mojo::File 'path';
use Test::More;
use JSON::Validator;

eval { JSON::Validator->new->schema('data://main/spec.json') };
like $@, qr{Could not find.*/definitions/Pet"}, 'missing definition';

my $workdir = path(__FILE__)->dirname;
eval { JSON::Validator->new->schema(path($workdir, 'spec', 'missing-ref.json')) };
like $@, qr{Unable to load schema.*missing\.json}, 'missing file';

done_testing;

__DATA__
@@ spec.json
{
  "schema": {
    "type": "array",
    "items": { "$ref": "#/definitions/Pet" }
  }
}
