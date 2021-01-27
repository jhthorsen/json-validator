use lib '.';
use t::Helper;
use JSON::Validator::Schema::Draft6;

t::Helper->schema(JSON::Validator::Schema::Draft6->new);

t::Helper->test(number => qw(basic maximum minimum));
t::Helper->test(array  => qw(basic items additional_items contains min_max unique));
t::Helper->test(object => qw(basic properties));
t::Helper->test(object => qw(additional_properties pattern_properties min_max names));

subtest 'exclusiveMaximum' => sub {
  schema_validate_ok 2.4, {exclusiveMaximum => 2.4}, E('/', '2.4 >= maximum(2.4)');
  schema_validate_ok 0,   {exclusiveMaximum => 0},   E('/', '0 >= maximum(0)');
};

subtest 'exclusiveMinimum' => sub {
  schema_validate_ok 4.2, {exclusiveMinimum => 4.2}, E('/', '4.2 <= minimum(4.2)');
  schema_validate_ok 0,   {exclusiveMinimum => 0},   E('/', '0 <= minimum(0)');
};

done_testing;
