use lib '.';
use t::Helper;
use Test::More;

my $schema = {properties => {v => {type => 'boolean'}}};

validate_ok {v => '0'},     $schema, E('/v', 'Expected boolean - got string.');
validate_ok {v => 'false'}, $schema, E('/v', 'Expected boolean - got string.');
validate_ok {v => 1},       $schema, E('/v', 'Expected boolean - got number.');
validate_ok {v => 0.5},     $schema, E('/v', 'Expected boolean - got number.');
validate_ok {v => Mojo::JSON->true},  $schema;
validate_ok {v => Mojo::JSON->false}, $schema;

t::Helper->validator->coerce(booleans => 1);
validate_ok {v => !!1},     $schema;
validate_ok {v => !!0},     $schema;
validate_ok {v => 'false'}, $schema;
validate_ok {v => 'true'},  $schema;
validate_ok {v => 1},       $schema;
validate_ok {v => 0.5},     $schema;
validate_ok {v => '1'},     $schema, E('/v', 'Expected boolean - got string.');
validate_ok {v => '0'},     $schema, E('/v', 'Expected boolean - got string.');
validate_ok {v => ''},      $schema, E('/v', 'Expected boolean - got string.');

SKIP: {
  skip 'YAML::XS is not installed', 1
    unless eval q[require YAML::XS;YAML::XS->VERSION('0.67');1];
  my $data = t::Helper->validator->_load_schema_from_text(\"---\nv: true\n");
  isa_ok($data->{v}, 'JSON::PP::Boolean');
  validate_ok $data, $schema;
}

SKIP: {
  skip 'boolean not installed', 1 unless eval 'require boolean;1';
  validate_ok {type => 'boolean'},
    {type => 'object', properties => {type => {type => 'string'}}};
}

SKIP: {
  skip 'Cpanel::JSON::XS not installed', 2
    unless eval 'require Cpanel::JSON::XS;1';
  validate_ok {disabled => Mojo::JSON->true},
    {properties => {disabled => {type => 'boolean'}}};
  validate_ok {disabled => Mojo::JSON->false},
    {properties => {disabled => {type => 'boolean'}}};
}

done_testing;
