use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

use lib 't/blog/lib';
plan skip_all => $@ unless my $t = eval { Test::Mojo->new('Blog') };

$t->get_ok('/')->status_is(302);

done_testing;
