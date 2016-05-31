use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new;
my @errors = $validator->validate({id => 1}, {type => 'object'});
is "@errors", "", "object";

done_testing;
