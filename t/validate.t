BEGIN {
  use File::Spec;
  $ENV{SWAGGER2_CACHE_DIR} = File::Spec->catdir(qw( t data cache ));
}

use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Swagger2;

plan skip_all => "Cannot read $Swagger2::SPEC_FILE" unless -r $Swagger2::SPEC_FILE;

$SIG{__DIE__} = sub { Carp::confess($_[0]) };
my $swagger;

{
  $swagger = Swagger2->new('t/data/petstore.json');
  is_deeply [$swagger->validate], [], 'petstore.json';
}

{
  local $swagger->tree->data->{foo} = 123;
  is_deeply [$swagger->validate], ['/: Properties not allowed: foo.'], 'petstore.json with foo';
}

{
  local $swagger->tree->data->{info}{'x-foo'} = 123;
  is_deeply [$swagger->validate], [], 'petstore.json with x-foo';
}


done_testing;
