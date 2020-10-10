use lib '.';
use t::Helper;
use JSON::Validator::Schema::Draft201909;

t::Helper->schema(JSON::Validator::Schema::Draft201909->new);

t::Helper->test(number => qw(basic maximum minimum));
t::Helper->test(array  => qw(basic items additional_items contains min_max));
t::Helper->test(array  => qw(unique unevaluated_items));
t::Helper->test(object => qw(basic properties));
t::Helper->test(object => qw(additional_properties pattern_properties min_max names));
t::Helper->test(object => qw(dependent_required dependent_schemas unevaluated_properties));

done_testing;
