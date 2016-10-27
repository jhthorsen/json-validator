use Mojo::Base -strict;

use File::Spec;
use Mojo::Util;
use Test::More tests => 3;

ok(
  module_calls_deprecated('JSON::Validator::OpenAPI'),
  "JSON::Validator::OpenAPI->validate_request is deprecated"
);

ok(
  !module_calls_deprecated('JSON::Validator::OpenAPI::Dancer2'),
  "JSON::Validator::OpenAPI::Dancer2->validate_request isn't deprecated"
);

ok(
  !module_calls_deprecated('JSON::Validator::OpenAPI::Mojolicious'),
  "JSON::Validator::OpenAPI::Mojolicious->validate_request isn't deprecated"
);

sub module_calls_deprecated {
  my $module = shift;

  my $called = 0;
  {
    no warnings 'redefine';
    *Mojo::Util::deprecated = sub { ++$called };
  }

  my $c      = {};
  my $schema = {parameters => [{name => 'foo', in => 'query', type => 'integer'}]};
  my $input  = {};

  eval "require $module" or die $@;

  eval {    # we don't care if this actually works out
    $module->new->validate_request($c, $schema, $input);
  };

  return $called;
}
