use Mojo::Base -strict;
use Mojo::File 'path';
use Test::More;
use JSON::Validator;

my $workdir = path(__FILE__)->to_abs->dirname;
my $jv      = JSON::Validator->new;
my $bundled;

{
  note 'bundle files';
  local $ENV{JSON_VALIDATOR_CACHE_ANYWAYS} = 1;
  $jv->_load_schema_from_url("http://json-schema.org/draft-04/schema");
  $jv->_load_schema_from_url("http://json-schema.org/draft-06/schema");
  $jv->_load_schema_from_url("http://json-schema.org/draft-07/schema");
}

note 'Run multiple times to make sure _reset() works';
for my $n (1 .. 3) {
  note "[$n] replace=1";
  $bundled = $jv->bundle({
    replace => 1,
    schema  => {
      name       => {'$ref'  => '#/components/schemas/name'},
      components => {schemas => {name => {type => 'string'}}}
    },
  });

  is $bundled->{name}{type}, 'string', "[$n] replace=1";

  note "[$n] replace=0";
  $bundled = $jv->schema({
    name       => {'$ref'  => '#/components/schemas/name'},
    age        => {'$ref'  => 'b.json#/components/schemas/age'},
    components => {schemas => {name => {type => 'string'}}},
    B =>
      {id => 'b.json', components => {schemas => {age => {type => 'integer'}}}},
  })->bundle;
  is $bundled->{components}{schemas}{name}{type}, 'string',
    "[$n] name still in components/schemas";
  is $bundled->{components}{schemas}{age}{type}, 'integer',
    "[$n] added to components/schemas";
  isnt $bundled->{age}, $jv->schema->get('/age'),  "[$n] new age ref";
  is $bundled->{name},  $jv->schema->get('/name'), "[$n] same name ref";
  is $bundled->{age}{'$ref'}, '#/components/schemas/age',
    "[$n] age \$ref point to /components/schemas/age";
  is $bundled->{name}{'$ref'}, '#/components/schemas/name',
    "[$n] name \$ref point to /components/schemas/name";
}

is $jv->get([qw(name type)]), 'string', 'get /name/$ref';
is $jv->get('/name/type'), 'string', 'get /name/type';
is $jv->get('/name/$ref'), undef,    'get /name/$ref';
is $jv->schema->get('/name/type'), 'string', 'schema get /name/type';
is $jv->schema->get('/name/$ref'), '#/components/schemas/name',
  'schema get /name/$ref';

$bundled = $jv->schema('data://main/bundled.json')->bundle;
is_deeply [sort keys %{$bundled->{components}{schemas}}], ['objtype'],
  'no dup components/schemas';

my @pathlists = (
  ['spec', 'with-deep-mixed-ref-components.json'],
  ['spec', File::Spec->updir, 'spec', 'with-deep-mixed-ref-components.json'],
);
for my $pathlist (@pathlists) {
  my $file = path $workdir, @$pathlist;
  $bundled = $jv->schema($file)->bundle;
  is_deeply [sort map { s!^[a-z0-9]{10}!SHA!; $_ }
      keys %{$bundled->{components}{schemas}}],
    [qw(
    SHA-age_json
    SHA-unit_json
    SHA-weight_json
    height
    )],
    'right components schemas in disk spec'
    or diag explain $bundled->{components};
}

note 'ensure filenames with funny characters not mangled by Mojo::URL';
my $file3 = path $workdir, 'spec', 'space bundle components.json';
eval { $bundled = $jv->schema($file3)->bundle };
is $@, '', 'loaded absolute filename with space';
is $bundled->{properties}{age}{description}, 'Age in years',
  'right components schemas in disk spec'
  or diag explain $bundled;

note 'extract subset of schema';
$jv->schema('data://main/bundled.json');
$bundled = $jv->bundle({schema => $jv->get([qw(paths /withdots get)])});
is_deeply(
  $bundled,
  {
    components => {
      schemas => {
        objtype =>
          {properties => {propname => {type => 'string'}}, type => 'object'}
      }
    },
    responses => {200 => {schema => {'$ref' => '#/components/schemas/objtype'}}}
  },
  'subset of schema was bundled'
) or diag explain $bundled;

note 'no leaking path';
my $ref_name_prefix = $workdir;
$ref_name_prefix =~ s![^\w-]!_!g;
$jv->schema(path $workdir, 'spec',
  'bundle-no-leaking-filename-components.json');
$bundled = $jv->bundle({ref_key => 'xyz'});
my @components = keys %{$bundled->{xyz}};
ok @components, 'components are present';
is_deeply [grep { 0 == index $_, $ref_name_prefix } @components], [],
  'no leaking of path';

done_testing;

__DATA__
@@ bundled.json
{
  "components": {
    "schemas": {
      "objtype": {
        "type": "object",
        "properties": {"propname": {"type": "string"}}
      }
    }
  },
  "paths": {
    "/withdots": {
      "get": {
        "responses": {
          "200": {"schema": {"$ref": "#/components/schemas/objtype"}}
        }
      }
    }
  }
}
