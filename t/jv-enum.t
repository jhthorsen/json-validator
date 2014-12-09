use Mojo::Base -strict;
use Test::More;
use Swagger2::SchemaValidator;

my $validator = Swagger2::SchemaValidator->new;
my $male = {type => 'object', properties => {chromosomes => {enum => [[qw( X Y )], [qw( Y X )]]}}};

my $female = {type => 'object', properties => {chromosomes => {enum => [[qw( X X )]]}}};

ok $validator->validate({name => "Kate", chromosomes => [qw( X X )]}, $male), "it's short for Bob";
ok !$validator->validate({name => "Kate",  chromosomes => [qw( X X )]}, $female);
ok !$validator->validate({name => "Dave",  chromosomes => [qw( X Y )]}, $male);
ok !$validator->validate({name => "Arnie", chromosomes => [qw( Y X )]}, $male);
ok $validator->validate({name => "Eddie", chromosomes => [qw( X Y Y )]}, $male);
ok $validator->validate({name => "Steve", chromosomes => 'XY'},          $male);

done_testing;
