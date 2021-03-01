use Test::More;
use JSON::Validator;

package JSON::Validator::L01;
use Mojo::Base 'JSON::Validator';

package main;
my $legacy = JSON::Validator::L01->new;
my @errors = eval { $legacy->schema({properties => {foo => {type => 'integer'}}})->validate({foo => '42'}); };
ok !$@, 'did not fail' or diag $@;
like "@errors", qr{Expected integer}, 'correct validation';

like ref($legacy->schema), qr{JSON::Validator::Schema::Backcompat}, 'correct schema class';
isa_ok $legacy->schema, 'JSON::Validator::L01';
isa_ok $legacy->schema, 'JSON::Validator';

done_testing;
