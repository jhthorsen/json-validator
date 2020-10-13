use lib '.';
use t::Helper;
use JSON::Validator::Schema::Draft201909;

my $schema = JSON::Validator::Schema::Draft201909->new;
t::Helper->schema($schema);

ok $schema->formats->{duration}, 'duration';
ok $schema->formats->{uuid},     'uuid';

t::Helper->test(number => qw(basic maximum minimum));
t::Helper->test(array  => qw(basic items additional_items contains min_max min_max_contains));
t::Helper->test(array  => qw(unique unevaluated_items));
t::Helper->test(object => qw(basic properties));
t::Helper->test(object => qw(additional_properties pattern_properties min_max names));
t::Helper->test(object => qw(dependent_required dependent_schemas unevaluated_properties));

note 'anchor';
$schema->data({'$ref' => '#foo', '$defs' => {'A' => {'$anchor' => 'foo', 'type' => 'integer'}}})->resolve;
is $schema->data->{type}, 'integer', 'foo anchor type';

note 'recursiveRef, without recursiveAnchor';
my $jv = JSON::Validator->new->schema('data://main/tree.json');
$jv->schema('data://main/recursiveRef.json');
isa_ok $jv->schema, 'JSON::Validator::Schema::Draft201909';
is $jv->schema->data->{type}, 'object', 'recursiveRef type';
is $jv->schema->data->{properties}{data}, true, 'recursiveRef properties data';
is $jv->schema->data->{properties}{children}{items}{type}, 'object', 'recursiveRef properties data items';
is $jv->schema->data->{properties}{children}{items}{properties}{children}{items}{type}, 'object', 'recursive';
is_deeply [sort keys %{$jv->store->schemas}],
  [qw(data://main/recursiveRef.json data://main/tree.json urn:recursiveRef urn:tree)], 'schemas in the store';

{
  no warnings 'redefine';
  local *JSON::Validator::_load_from_data = sub { die 'not cached' };
  ok eval { JSON::Validator->new->schema('data://main/tree.json') }, 'cached' or diag $@;
}

done_testing;

__DATA__
@@ tree.json
{
  "$schema": "https://json-schema.org/draft/2019-09/schema",
  "$id": "urn:tree",
  "type": "object",
  "properties": {
    "data": true,
    "children": {
      "type": "array",
      "items": {"$recursiveRef": "#"}
    }
  }
}
@@ recursiveRef.json
{
  "$schema": "https://json-schema.org/draft/2019-09/schema",
  "$id": "urn:recursiveRef",
  "$ref": "urn:tree"
}
