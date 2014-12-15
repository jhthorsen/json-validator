use Mojo::Base -strict;
use Test::More;
use Swagger2::SchemaValidator;

my $validator = Swagger2::SchemaValidator->new;
my $schema = {type => 'object', properties => {v => {type => 'string'}}};
my @errors;

{
  $schema->{properties}{v}{format} = 'byte';
  @errors = $validator->validate({v => 'amh0aG9yc2Vu'}, $schema);
  is "@errors", "", "byte valid";
  @errors = $validator->validate({v => "\0"}, $schema);
  is "@errors", "/v: Does not match byte format.", "byte invalid";
}

{
  $schema->{properties}{v}{format} = 'date';
  @errors = $validator->validate({v => '2014-12-09'}, $schema);
  is "@errors", "", "date valid";
  @errors = $validator->validate({v => '2014-12-09T20:49:37Z'}, $schema);
  is "@errors", "/v: Does not match date format.", "date invalid";
}

{
  $schema->{properties}{v}{format} = 'date-time';
  @errors = $validator->validate({v => '2014-12-09T20:49:37Z'}, $schema);
  is "@errors", "", "date-time valid";
  @errors = $validator->validate({v => '20:46:02'}, $schema);
  is "@errors", "/v: Does not match date-time format.", "date-time invalid";
}

{
  local $schema->{properties}{v}{type}   = 'number';
  local $schema->{properties}{v}{format} = 'double';
  @errors = $validator->validate({v => 1.1000000238418599085576943252817727625370025634765626}, $schema);
  local $TODO = "cannot test double, since input is already rounded";
  is "@errors", "", "positive double valid";
}

{
  local $schema->{properties}{v}{format} = 'email';
  @errors = $validator->validate({v => 'jhthorsen@cpan.org'}, $schema);
  is "@errors", "", "email valid";
  @errors = $validator->validate({v => 'foo'}, $schema);
  is "@errors", "/v: Does not match email format.", "email invalid";
}

{
  local $TODO                            = 'No idea how to test floats';
  local $schema->{properties}{v}{type}   = 'number';
  local $schema->{properties}{v}{format} = 'float';
  @errors = $validator->validate({v => -1.10000002384186}, $schema);
  is "@errors", "", "negative float valid";
  @errors = $validator->validate({v => 1.10000002384186}, $schema);
  is "@errors", "", "positive float valid";
  @errors = $validator->validate({v => 0.10000000000000}, $schema);
  is "@errors", "/v: Does not match float format.", "float invalid";
}

if (Swagger2::SchemaValidator::VALIDATE_HOSTNAME) {
  local $schema->{properties}{v}{format} = 'hostname';
  @errors = $validator->validate({v => 'mojolicio.us'}, $schema);
  is "@errors", "", "hostname valid";
  @errors = $validator->validate({v => '[]'}, $schema);
  is "@errors", "/v: Does not match hostname format.", "hostname invalid";
}
else {
  diag "Data::Validate::Domain is not installed";
}

{
  local $schema->{properties}{v}{format} = 'ipv4';
  @errors = $validator->validate({v => '255.100.30.1'}, $schema);
  is "@errors", "", "ipv4 valid";
  @errors = $validator->validate({v => '300.0.0.0'}, $schema);
  is "@errors", "/v: Does not match ipv4 format.", "ipv4 invalid";
}

if (Swagger2::SchemaValidator::VALIDATE_IP) {
  local $schema->{properties}{v}{format} = 'ipv6';
  @errors = $validator->validate({v => '::1'}, $schema);
  is "@errors", "", "ipv6 valid";
  @errors = $validator->validate({v => '300.0.0.0'}, $schema);
  is "@errors", "/v: Does not match ipv6 format.", "ipv6 invalid";
}
else {
  diag "Data::Validate::IP is not installed";
}

{
  local $schema->{properties}{v}{type}   = 'integer';
  local $schema->{properties}{v}{format} = 'int32';
  @errors = $validator->validate({v => -2147483648}, $schema);
  is "@errors", "", "negative int32 valid";
  @errors = $validator->validate({v => 2147483647}, $schema);
  is "@errors", "", "positive int32 valid";
  @errors = $validator->validate({v => 2147483648}, $schema);
  is "@errors", "/v: Does not match int32 format.", "int32 invalid";
}

if (Swagger2::SchemaValidator::IV_SIZE >= 8) {
  local $schema->{properties}{v}{type}   = 'integer';
  local $schema->{properties}{v}{format} = 'int64';
  @errors = $validator->validate({v => -9223372036854775808}, $schema);
  is "@errors", "", "negative int64 valid";
  @errors = $validator->validate({v => 9223372036854775807}, $schema);
  is "@errors", "", "positive int64 valid";
  @errors = $validator->validate({v => 9223372036854775808}, $schema);
  is "@errors", "/v: Does not match int64 format.", "int64 invalid";
}

{
  local $schema->{properties}{v}{format} = 'uri';
  @errors = $validator->validate({v => 'http://mojolicio.us/?ø=123'}, $schema);
  is "@errors", "", "uri valid";
  local $TODO = "Not sure how to make an invalid URI";
  @errors = $validator->validate({v => 'anything'}, $schema);
  is "@errors", "/v: Does not match uri format.", "uri invalid";
}

{
  local $schema->{properties}{v}{format} = 'unknown';
  @errors = $validator->validate({v => 'whatever'}, $schema);
  is "@errors", "", "unknown is always valid";
}

done_testing;
