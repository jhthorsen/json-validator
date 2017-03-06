use lib '.';
use t::Helper;

my $male = {type => 'object', properties => {chromosomes => {enum => [[qw(X Y)], [qw(Y X)]]}}};
my $female = {type => 'object', properties => {chromosomes => {enum => [[qw(X X)]]}}};

validate_ok {name => "Kate",  chromosomes => [qw(X X)]}, $female;
validate_ok {name => "Dave",  chromosomes => [qw(X Y)]}, $male;
validate_ok {name => "Arnie", chromosomes => [qw(Y X)]}, $male;

validate_ok {name => "Kate", chromosomes => [qw(X X)]}, $male,
  E('/chromosomes', 'Not in enum list: ["X","Y"], ["Y","X"].');
validate_ok {name => "Eddie", chromosomes => [qw(X YY )]}, $male,
  E('/chromosomes', 'Not in enum list: ["X","Y"], ["Y","X"].');
validate_ok {name => "Steve", chromosomes => 'XY'}, $male,
  E('/chromosomes', 'Not in enum list: ["X","Y"], ["Y","X"].');

done_testing;
