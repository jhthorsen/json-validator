use lib '.';
use t::Helper;
use JSON::Validator::Schema::Draft7;

t::Helper->schema(JSON::Validator::Schema::Draft7->new);

t::Helper->test(number => qw(basic maximum minimum));
t::Helper->test(array  => qw(basic items additional_items contains min_max));
t::Helper->test(array  => qw(unique unevaluated_items));
t::Helper->test(object => qw(basic properties));
t::Helper->test(
  object => qw(additional_properties pattern_properties min_max names));
t::Helper->test(
  object => qw(dependent_required dependent_schemas unevaluated_properties));

note 'exclusiveMaximum';
schema_validate_ok 2.4, {exclusiveMaximum => 2.4},
  E('/', '2.4 >= maximum(2.4)');
schema_validate_ok 0, {exclusiveMaximum => 0}, E('/', '0 >= maximum(0)');

note 'exclusiveMinimum';
schema_validate_ok 4.2, {exclusiveMinimum => 4.2},
  E('/', '4.2 <= minimum(4.2)');
schema_validate_ok 0, {exclusiveMinimum => 0}, E('/', '0 <= minimum(0)');

note 'bundle';
my $bundle
  = JSON::Validator::Schema::Draft7->new('data://main/spec.json')->bundle;
is $bundle->data->{properties}{name}{'$ref'}, '#/$defs/_name', 'bundle ref';
is $bundle->data->{'$defs'}{_name}{type}, 'string', 'bundled spec under $defs';

done_testing;

__DATA__
@@ spec.json
{"type":"object","properties":{"name":{"$ref":"data://main/defs.json#/name"}}}
@@ defs.json
{"name":{"type":"string"}}
