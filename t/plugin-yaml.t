use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use Mojolicious;
use t::Api;

my $n = 0;

#
# This test checks that "require: false" is indeed false
# https://github.com/jhthorsen/swagger2/issues/39
#

for my $module (qw( YAML::XS YAML::Syck YAML::Tiny )) {
  unless (eval "require $module;1") {
    diag "Skipping test when $module is not installed";
    next;
  }

  no warnings 'once';
  local *Swagger2::LoadYAML = eval "\\\&$module\::Load";
  $n++;

  diag join ' ', $module, $module->VERSION || 0;

  if ($module eq 'YAML::Tiny' and $module->VERSION < 1.57) {
    diag 'YAML::Tiny < 1.57 is not supported';
    next;
  }

  my $app = Mojolicious->new;
  unless (eval { $app->plugin(Swagger2 => {url => 't/data/petstore.yaml'}); 1 }) {
    diag $@;
    ok 0, "Could not load Swagger2 plugin using $module";
    next;
  }

  my $t = Test::Mojo->new($app);

  $t::Api::RES = [{id => 123, name => "kit-cat"}];
  $t->get_ok('/v1/pets')->status_is(200)->json_is('/0/id', 123)->json_is('/0/name', 'kit-cat');
}

ok 1, 'no yaml modules available' unless $n;

done_testing;
