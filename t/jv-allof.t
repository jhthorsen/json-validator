use t::Helper;
use Test::More;

my $schema = {allOf => [{type => 'string', maxLength => 5}, {type => 'string', minLength => 3}]};
validate_ok $schema, 'short', [];
validate_ok $schema, 12, [E('/', 'Expected string, got number.')];

$schema = {allOf => [{type => 'string', maxLength => 7}, {type => 'string', maxLength => 5}]};
validate_ok $schema, 'superlong',
  [E('/', 'allOf[0]: String is too long: 9/7.'), E('/', 'allOf[1]: String is too long: 9/5.')];
validate_ok $schema, 'toolong', [E('/', 'allOf[1]: String is too long: 7/5.')];
validate_ok $schema, 'short', [];

done_testing;
