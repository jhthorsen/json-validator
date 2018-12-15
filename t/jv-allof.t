use lib '.';
use t::Helper;

my $schema
  = {allOf =>
    [{type => 'string', maxLength => 5}, {type => 'string', minLength => 3}]
  };

validate_ok 'short', $schema;
validate_ok 12, $schema, E('/', '/allOf Expected string - got number.');

$schema
  = {allOf =>
    [{type => 'string', maxLength => 7}, {type => 'string', maxLength => 5}]
  };
validate_ok 'superlong', $schema, E('/', '/allOf/0 String is too long: 9/7.'),
  E('/', '/allOf/1 String is too long: 9/5.');
validate_ok 'toolong', $schema, E('/', '/allOf/1 String is too long: 7/5.');

done_testing;
