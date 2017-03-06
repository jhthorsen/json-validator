use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new;
my $schema = {type => 'object', properties => {v => {type => 'string'}}};
my @errors;

{
  $schema->{properties}{v}{format} = 'date-time';

  for my $dt (
    "2017-03-29T23:02:55.831Z",  "2017-03-29t23:02:55.01z",
    "2017-03-29 23:02:55-12:00", "2016-02-29T23:02:55+05:00"
    )
  {
    @errors = $validator->validate({v => $dt}, $schema);
    is "@errors", "", "date-time $dt valid";
  }

  for my $dt (
    "xxxx-xx-xxtxx:xx:xxz", "2017-03-29T23:02:60Z",
    "2017-03-29T23:61:55Z", "2017-03-29T24:02:55Z",
    "2017-03-32T23:02:55Z", "2017-02-30T23:02:55Z",
    "2017-02-29T23:02:55Z", "2017-13-29T23:02:55Z",
    "2017-03-00T23:02:55Z", "2017-00-29T23:02:55Z",
    "2017-03-29\t23:02:55-12:00",
    )
  {
    @errors = $validator->validate({v => $dt}, $schema);
    is "@errors", "/v: Does not match date-time format.", "date-time $dt invalid";
  }
}

{
  local $schema->{properties}{v}{format} = 'email';
  @errors = $validator->validate({v => 'jhthorsen@cpan.org'}, $schema);
  is "@errors", "", "email valid";
  @errors = $validator->validate({v => 'foo'}, $schema);
  is "@errors", "/v: Does not match email format.", "email invalid";
}

if (JSON::Validator::VALIDATE_HOSTNAME) {
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

if (JSON::Validator::VALIDATE_IP) {
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
  $schema->{properties}{v}{format} = 'regex';
  @errors = $validator->validate({v => '(\w+)'}, $schema);
  is "@errors", "", "regex valid";
  @errors = $validator->validate({v => '(\w'}, $schema);
  is "@errors", "/v: Does not match regex format.", "ipv6 invalid";
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
