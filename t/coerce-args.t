use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new;
my %coerce = (booleans => 1);
is_deeply($validator->coerce(%coerce)->coerce,  {booleans => 1}, 'hash is accepted');
is_deeply($validator->coerce(\%coerce)->coerce, {booleans => 1}, 'hash reference is accepted');
is_deeply($validator->coerce(1)->coerce, {%coerce, numbers => 1, strings => 1}, '1 is accepted');

done_testing;
