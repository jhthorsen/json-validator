use lib '.';
use t::Helper;
use Test::More;

my $schema = {properties => {v => {type => 'boolean'}}};

validate_ok {v => '0'},     $schema, E('/v', 'Expected boolean - got string.');
validate_ok {v => 'false'}, $schema, E('/v', 'Expected boolean - got string.');
validate_ok {v => Mojo::JSON->true},  $schema;
validate_ok {v => Mojo::JSON->false}, $schema;

t::Helper->validator->coerce(booleans => 1);
validate_ok {v => !!1},     $schema;
validate_ok {v => !!0},     $schema;
validate_ok {v => 'false'}, $schema;
validate_ok {v => 'true'},  $schema;
validate_ok {v => 1},       $schema, E('/v', 'Expected boolean - got number.');
validate_ok {v => '1'},     $schema, E('/v', 'Expected boolean - got string.');
validate_ok {v => '0'},     $schema, E('/v', 'Expected boolean - got string.');
validate_ok {v => ''},      $schema, E('/v', 'Expected boolean - got string.');

SKIP: {
  skip 'YAML::XS is not installed', 1 unless eval 'require YAML::XS;1';
  t::Helper->validator->coerce(booleans => 0);  # see that _load_schema_from_text() turns it back on
  my $data = t::Helper->validator->_load_schema_from_text(\"---\nv: true\n");
  validate_ok $data, $schema;
  ok(t::Helper->validator->coerce->{booleans}, 'coerce booleans');
}

SKIP: {
  skip 'boolean not installed', 1 unless eval 'require boolean;1';
  validate_ok {type => 'boolean'}, {type => 'object', properties => {type => {type => 'string'}}};
}

done_testing;
