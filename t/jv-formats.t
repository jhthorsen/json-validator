use Mojo::Base -strict;
use Test::More;
use Swagger2::SchemaValidator;

my $validator = Swagger2::SchemaValidator->new;
my $schema = {type => 'object', properties => {v => {type => 'string'}}};
my @errors;

{
  $schema->{properties}{v}{format} = 'date-time';
  @errors = $validator->validate({v => '2014-12-09T20:49:37Z'}, $schema);
  is "@errors", "", "date-time valid";
  @errors = $validator->validate({v => '20:46:02'}, $schema);
  is "@errors", "/v: Does not match date-time format.", "date-time invalid";
}

{
  local $schema->{properties}{v}{format} = 'email';
  @errors = $validator->validate({v => 'jhthorsen@cpan.org'}, $schema);
  is "@errors", "", "email valid";
  @errors = $validator->validate({v => 'foo'}, $schema);
  is "@errors", "/v: Does not match email format.", "email invalid";
}

if (Swagger2::SchemaValidator::VALIDATE_HOSTNAME) {
  local $schema->{properties}{v}{format} = 'hostname';
  @errors = $validator->validate({v => 'mojolicio.us'}, $schema);
  is "@errors", "", "hostname valid";
  @errors = $validator->validate({v => '[]'}, $schema);
  is "@errors", "/v: Does not match hostname format.", "hostname invalid";
}
else {
  skip "Data::Validate::Domain is not installed", 1;
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
  skip "Data::Validate::IP is not installed", 1;
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
