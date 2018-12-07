use Mojo::Base -strict;
use JSON::Validator;
use Test::More;

# Note that you might have to run this test many times before it fails:
# while TEST_RANDOM_ITERATIONS=10000 prove -l t/random-errors.t; do echo "---"; done
plan skip_all => 'TEST_RANDOM_ITERATIONS=10000'
  unless my $iterations = $ENV{TEST_RANDOM_ITERATIONS};

my $validator = JSON::Validator->new->schema({
  items => {
    properties => {
      prop1 => {type => [qw(string null)]},
      prop2 => {type => [qw(string null)], format => 'ipv4'},
      prop3 => {type => [qw(string null)], format => 'ipv4'},
      prop4 => {type => 'string', enum => [qw(foo bar)]},
      prop5 => {type => [qw(string null)]},
      prop6 => {type => 'string'},
      prop7 => {type => 'string', enum => [qw(foo bar)]},
      prop8 => {type => [qw(string null)], format => 'ipv4'},
      prop9 => {type => [qw(string null)]},
    },
    type => 'object',
  },
  type => 'array',
});

my @errors;
for (1 .. $iterations) {
  push @errors,
    $validator->validate([{
    prop1 => undef,
    prop2 => undef,
    prop3 => undef,
    prop4 => 'foo',
    prop5 => undef,
    prop6 => 'foo',
    prop7 => 'bar',
    prop8 => undef,
    prop9 => undef,
    }]);
  last if @errors;
}

ok !@errors, 'no random error' or diag @errors;

done_testing;
