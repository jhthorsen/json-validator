use Mojo::Base -strict;

use JSON::Validator;
use Test::More;

my $jv          = JSON::Validator->new;
my $broken_data = {ant => [qw(fire soldier termite)], bat => 'cricket', cat => 'lion', dog => 'good boy'};
my $num_errors;

# The schema below gets turned into a perl hash inside JSON::Validator,
# so looping around like this will execute the test with all kinds of
# different internal ordering
for (1 .. 20) {
  $jv->schema(my $schema_text
      = '{ "type": "object", "properties": { "ant": { "type": "string" }, "bat": { "type": "array" }, "cat": { "type": "object" }, "dog": { "type": "integer" } } }'
  );
  my @errors = $jv->validate($broken_data);
  is_deeply([map { $_->path } @errors], [qw(/ant /bat /cat /dog)], "got errors in expected order");
  if (!$num_errors) {    # only run this test once
    $num_errors = $jv->validate($broken_data);
    is($num_errors, 4, "in scalar context got the right number of errors");
  }
}

done_testing;
