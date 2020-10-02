use strict;
use warnings;

use JSON::Validator;
use Math::Permute::List;
use Test::More;

my $jv = JSON::Validator->new();
permute {
    $jv->schema(my $schema_text = join('',
       '{ "type": "object", "properties": {',
       join(', ', @_),
       '}}'
    ));
    my @errors = $jv->validate({
        ant => [qw(fire soldier termite)],
        bat => 'cricket',
        cat => 'lion',
        dog => 'good boy'
    });
    is_deeply(
        [map { $_->path() } @errors],
        [qw(/ant /bat /cat /dog)],
        "got errors in expected order with schema: $schema_text"
    );
} (
    '"ant": { "type": "string" }',
    '"bat": { "type": "array" }',
    '"cat": { "type": "object" }',
    '"dog": { "type": "integer" }',
);

done_testing();
