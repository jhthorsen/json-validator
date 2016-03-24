use Mojo::Base -strict;
use Test::More;

my $i   = 0;
my $doc = <<'HERE';
---
foo:
  - '$ref': '#/parameters/Foo'
HERE

for my $module (qw( YAML::XS YAML::Syck )) {
  next unless eval "require $module;1";
  my $loader = eval "\\\&$module\::Load";
  is_deeply eval { $loader->($doc) } || undef, {foo => [{'$ref' => '#/parameters/Foo'}]},
    "loaded with $module";
  $i++;
}

plan skip_all => 'No YAML module was installed' unless $i;

done_testing;
