use Mojo::Base -strict;
use Mojo::File 'path';
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new;
my $bundled;

# Bundle files
{
  local $ENV{JSON_VALIDATOR_CACHE_ANYWAYS} = 1;
  $validator->_load_schema_from_url("http://json-schema.org/draft-04/schema");
  $validator->_load_schema_from_url("http://json-schema.org/draft-06/schema");
  $validator->_load_schema_from_url("http://json-schema.org/draft-07/schema");
}

# Run multiple times to make sure _reset() works
for my $n (1 .. 3) {
  note "[$n] replace=1";
  $bundled = $validator->bundle({
    ref_key => 'definitions',
    replace => 1,
    schema  => {
      name        => {'$ref' => '#/definitions/name'},
      definitions => {name   => {type => 'string'}}
    },
  });

  is $bundled->{name}{type}, 'string', "[$n] replace=1";

  note "[$n] replace=0";
  $bundled = $validator->schema({
    name        => {'$ref' => '#/definitions/name'},
    age         => {'$ref' => 'b.json#/definitions/age'},
    definitions => {name   => {type => 'string'}},
    B => {id => 'b.json', definitions => {age => {type => 'integer'}}},
  })->bundle({ref_key => 'definitions'});
  is $bundled->{definitions}{name}{type}, 'string',
    "[$n] name still in definitions";
  is $bundled->{definitions}{b_json__definitions_age}{type}, 'integer',
    "[$n] added to definitions";
  isnt $bundled->{age}, $validator->schema->get('/age'),  "[$n] new age ref";
  is $bundled->{name},  $validator->schema->get('/name'), "[$n] same name ref";
  is $bundled->{age}{'$ref'}, '#/definitions/b_json__definitions_age',
    "[$n] age \$ref point to /definitions/b_json__definitions_age";
  is $bundled->{name}{'$ref'}, '#/definitions/name',
    "[$n] name \$ref point to /definitions/name";
}

is $validator->get([qw(name type)]), 'string', 'get /name/$ref';
is $validator->get('/name/type'), 'string', 'get /name/type';
is $validator->get('/name/$ref'), undef,    'get /name/$ref';
is $validator->schema->get('/name/type'), 'string', 'schema get /name/type';
is $validator->schema->get('/name/$ref'), '#/definitions/name',
  'schema get /name/$ref';

$bundled = $validator->schema('data://main/api.json')
  ->bundle({ref_key => 'definitions'});
is_deeply [sort keys %{$bundled->{definitions}}], ['objtype'],
  'no dup definitions';

my @pathlists = (
  ['spec', 'with-deep-mixed-ref.json'],
  ['spec', File::Spec->updir, 'spec', 'with-deep-mixed-ref.json'],
);
for my $pathlist (@pathlists) {
  my $file = path(path(__FILE__)->dirname, @$pathlist);
  $bundled = $validator->schema($file)->bundle({ref_key => 'definitions'});
  is_deeply [sort map { s!^[a-z0-9]{10}!SHA!; $_ }
      keys %{$bundled->{definitions}}], [
    qw(
      SHA-age.json
      SHA-unit.json
      SHA-weight.json
      height
      )
      ],
    'right definitions in disk spec'
    or diag explain $bundled->{definitions};
}

# ensure filenames with funny characters not mangled by Mojo::URL
my $file3 = path(__FILE__)->sibling('spec', 'space bundle.json');
eval { $bundled = $validator->schema($file3)->bundle };
is $@, '', 'loaded absolute filename with space';
is $bundled->{properties}{age}{description}, 'Age in years',
  'right definitions in disk spec'
  or diag explain $bundled;

done_testing;

__DATA__

@@ api.json
{
   "definitions" : {
      "objtype" : {
         "type" : "object",
         "properties" : { "propname" : { "type" : "string" } }
      }
   },
   "paths" : {
      "/withdots" : {
         "get" : {
            "responses" : {
               "200" : { "schema" : { "$ref" : "#/definitions/objtype" } }
            }
         }
      }
   }
}
