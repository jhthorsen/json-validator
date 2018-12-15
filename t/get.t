use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $jv = JSON::Validator->new->schema(
  {
    foo => [{y => 'foo'}],
    bar => [{y => 'first'}, {y => 'second'}, {z => 'zzz'}],
  }
);

is $jv->get('/bar/2/z'), 'zzz', 'get /bar/2/z';
is $jv->get([qw(nope 404)]), undef, 'get /nope/404';
is_deeply $jv->get([qw(bar 0)]), {y => 'first'}, 'get /bar/0';

# This is not officially supported. I think maybe the callback version is the way to go,
# since it allows the JSON pointer to be passed on as well.
is_deeply $jv->get(['bar', undef, 'y']), ['first', 'second', undef],
  'get /bar/undef/y';
is_deeply $jv->get([undef, undef, 'y']), [['first', 'second', undef], ['foo']],
  'get /undef/undef/y';
is_deeply $jv->get([undef, undef, 'y'])->flatten,
  ['first', 'second', undef, 'foo'], 'get /undef/undef/y flatten';

done_testing;
