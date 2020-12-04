use Mojo::Base -strict;

use Test::More;
use JSON::Validator;

my @warnings;
$SIG{__WARN__} = sub { push @warnings, @_ };

JSON::Validator->new->schema(q!{ "type": "object" }!."\n");

ok(!@warnings, "no warning emitted when ->schema() method is passed a valid JSON schema ending in newline");

done_testing;
