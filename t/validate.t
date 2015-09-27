use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Swagger2;

my $swagger = Swagger2->new('t/data/validate.json');
my @errors  = $swagger->validate;
is_deeply \@errors, [], 'petstore.json' or diag join "\n", @errors;

$swagger = Swagger2->new('t/data/validate.json');
local $swagger->api_spec->data->{foo} = 123;
@errors = $swagger->validate;
is_deeply \@errors, ['/: Properties not allowed: foo.'], 'petstore.json with foo' or diag join "\n", @errors;

$swagger = Swagger2->new('t/data/validate.json');
local $swagger->api_spec->data->{info}{'x-foo'} = 123;
@errors = $swagger->validate;
is_deeply \@errors, [], 'petstore.json with x-foo' or diag join "\n", @errors;

done_testing;
