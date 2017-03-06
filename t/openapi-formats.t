use lib '.';
use JSON::Validator::OpenAPI::Mojolicious;
use t::Helper;
use Test::More;

$ENV{TEST_VALIDATOR_CLASS} = 'JSON::Validator::OpenAPI::Mojolicious';

my $schema = {type => 'object', properties => {v => {type => 'string'}}};

{
  $schema->{properties}{v}{format} = 'byte';
  validate_ok {v => 'amh0aG9yc2Vu'}, $schema;
  validate_ok {v => "\0"}, $schema, E('/v', 'Does not match byte format.');
}

{
  $schema->{properties}{v}{format} = 'date';
  validate_ok {v => '2014-12-09'}, $schema;
  validate_ok {v => '2014-12-09T20:49:37Z'}, $schema, E('/v', 'Does not match date format.');
}

{
  $schema->{properties}{v}{format} = 'date-time';
  validate_ok {v => '2014-12-09T20:49:37Z'}, $schema;
  validate_ok {v => '20:46:02'}, $schema, E('/v', 'Does not match date-time format.');
}

{
  local $schema->{properties}{v}{type}   = 'number';
  local $schema->{properties}{v}{format} = 'double';
  local $TODO                            = "cannot test double, since input is already rounded";
  validate_ok {v => 1.1000000238418599085576943252817727625370025634765626}, $schema;
}

{
  local $schema->{properties}{v}{format} = 'email';
  validate_ok {v => 'jhthorsen@cpan.org'}, $schema;
  validate_ok {v => 'foo'}, $schema, E('/v', 'Does not match email format.');
}

{
  local $TODO                            = 'No idea how to test floats';
  local $schema->{properties}{v}{type}   = 'number';
  local $schema->{properties}{v}{format} = 'float';
  validate_ok {v => -1.10000002384186}, $schema;
  validate_ok {v => 1.10000002384186},  $schema;
  validate_ok {v => 0.10000000000000},  $schema, E('/v', 'Does not match float format.');
}

{
  local $schema->{properties}{v}{format} = 'ipv4';
  validate_ok {v => '255.100.30.1'}, $schema;
  validate_ok {v => '300.0.0.0'}, $schema, E('/v', 'Does not match ipv4 format.');
}

{
  local $schema->{properties}{v}{type}   = 'integer';
  local $schema->{properties}{v}{format} = 'int32';
  validate_ok {v => -2147483648}, $schema;
  validate_ok {v => 2147483647},  $schema;
  validate_ok {v => 2147483648},  $schema, E('/v', 'Does not match int32 format.');
}

if (JSON::Validator::OpenAPI::IV_SIZE >= 8) {
  local $schema->{properties}{v}{type}   = 'integer';
  local $schema->{properties}{v}{format} = 'int64';
  validate_ok {v => -9223372036854775808}, $schema;
  validate_ok {v => 9223372036854775807},  $schema;
  validate_ok {v => 9223372036854775808},  $schema, E('/v', 'Does not match int64 format.');
}

{
  local $schema->{properties}{v}{format} = 'uri';
  validate_ok {v => 'http://mojolicio.us/?ø=123'}, $schema;
  local $TODO = "Not sure how to make an invalid URI";
  validate_ok {v => 'anything'}, $schema, E('/v', 'Does not match uri format.');
}

{
  local $schema->{properties}{v}{format} = 'password';
  validate_ok {v => 'whatever'}, $schema;
}

{
  local $schema->{properties}{v}{format} = 'unknown';
  validate_ok {v => 'whatever'}, $schema;
}

done_testing;
