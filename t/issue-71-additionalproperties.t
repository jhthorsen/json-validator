use lib '.';
use t::Helper;
use Test::More;

my $schema = {
  required             => ['link'],
  type                 => 'object',
  additionalProperties => false,
  properties           => {link => {format => 'uri'}},
};

validate_ok {haha => 'hehe', link => 'http://a'}, $schema,
  E('/', 'Properties not allowed: haha.');

done_testing;
