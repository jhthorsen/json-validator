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
$schema->data('data://main/tree.json')->resolve;
$schema->data('data://main/recursiveRef.json')->resolve;
is $schema->data->{type}, 'object', 'recursiveRef type';
is $schema->data->{properties}{data}, true, 'recursiveRef properties data';
is $schema->data->{properties}{children}{items}{type}, 'object', 'recursiveRef properties data items';
is $schema->data->{properties}{children}{items}{properties}{children}{items}{type}, 'object', 'recursive';

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
