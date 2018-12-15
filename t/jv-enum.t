use lib '.';
use t::Helper;

my $male = {
  type       => 'object',
  properties => {chromosomes => {enum => [[qw(X Y)], [qw(Y X)]]}}
};
my $female
  = {type => 'object', properties => {chromosomes => {enum => [[qw(X X)]]}}};

validate_ok {name => "Kate",  chromosomes => [qw(X X)]}, $female;
validate_ok {name => "Dave",  chromosomes => [qw(X Y)]}, $male;
validate_ok {name => "Arnie", chromosomes => [qw(Y X)]}, $male;

validate_ok {name => "Kate", chromosomes => [qw(X X)]}, $male,
  E('/chromosomes', 'Not in enum list: ["X","Y"], ["Y","X"].');
validate_ok {name => "Eddie", chromosomes => [qw(X YY )]}, $male,
  E('/chromosomes', 'Not in enum list: ["X","Y"], ["Y","X"].');
validate_ok {name => "Steve", chromosomes => 'XY'}, $male,
  E('/chromosomes', 'Not in enum list: ["X","Y"], ["Y","X"].');

# https://github.com/jhthorsen/json-validator/issues/69
validate_ok(
  {some_prop => ['foo']},
  {
    type       => 'object',
    required   => ['some_prop'],
    properties => {
      some_prop => {
        type     => 'array',
        minItems => 1,
        maxItems => 1,
        items    => [{type => 'string', enum => [qw(x y)]}],
      },
    },
  },
  E('/some_prop/0', 'Not in enum list: x, y.')
);

for my $v (undef, false, true) {
  validate_ok(
    {name => $v},
    {
      type     => 'object',
      required => ['name'],
      properties =>
        {name => {type => [qw(boolean null)], enum => [undef, false, true]}},
    },
  );
}

validate_ok(
  {name => undef},
  {
    type     => 'object',
    required => ['name'],
    properties =>
      {name => {type => ['string'], enum => [qw(n yes true false)]}},
  },
  E('/name', '/anyOf Expected string - got null.'),
  E('/name', 'Not in enum list: n, yes, true, false.'),
);

done_testing;
