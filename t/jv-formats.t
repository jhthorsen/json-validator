use lib '.';
use t::Helper;
use Test::More;

my $schema = {type => 'object', properties => {v => {type => 'string'}}};

{
  $schema->{properties}{v}{format} = 'date-time';

  validate_ok {v => $_},
    $schema
    for (
    '2017-03-29T23:02:55.831Z',  '2017-03-29t23:02:55.01z',
    '2017-03-29 23:02:55-12:00', '2016-02-29T23:02:55+05:00'
    );

  validate_ok {v => $_}, $schema,
    E('/v', 'Does not match date-time format.')
    for (
    'xxxx-xx-xxtxx:xx:xxz', '2017-03-29T23:02:60Z', '2017-03-29T23:61:55Z',
    '2017-03-29T24:02:55Z', '2017-03-32T23:02:55Z', '2017-02-30T23:02:55Z',
    '2017-02-29T23:02:55Z', '2017-13-29T23:02:55Z', '2017-03-00T23:02:55Z',
    '2017-00-29T23:02:55Z', '2017-03-29\t23:02:55-12:00',
    );
}

{
  local $schema->{properties}{v}{format} = 'email';
  validate_ok {v => 'jhthorsen@cpan.org'}, $schema;
  validate_ok {v => 'foo'}, $schema, E('/v', 'Does not match email format.');
}

{
  local $TODO = JSON::Validator::VALIDATE_HOSTNAME ? undef : 'Install Data::Validate::Domain';
  local $schema->{properties}{v}{format} = 'hostname';
  validate_ok {v => 'mojolicio.us'}, $schema;
  validate_ok {v => '[]'}, $schema, E('/v', 'Does not match hostname format.');
}

{
  local $schema->{properties}{v}{format} = 'ipv4';
  validate_ok {v => '255.100.30.1'}, $schema;
  validate_ok {v => '300.0.0.0'}, $schema, E('/v', 'Does not match ipv4 format.');
}

{
  local $TODO = JSON::Validator::VALIDATE_IP ? undef : 'Install Data::Validate::IP';
  local $schema->{properties}{v}{format} = 'ipv6';
  validate_ok {v => '::1'}, $schema;
  validate_ok {v => '300.0.0.0'}, $schema, E('/v', 'Does not match ipv6 format.');
}

{
  local $schema->{properties}{v}{format} = 'regex';
  validate_ok {v => '(\w+)'}, $schema;
  validate_ok {v => '(\w'}, $schema, E('/v', 'Does not match regex format.');
}

{
  local $schema->{properties}{v}{format} = 'uri';
  validate_ok {v => 'http://mojolicio.us/?ø=123'}, $schema;
  validate_ok {v => '/relative-path'},              $schema, E('/v', 'Does not match uri format.');
  validate_ok {v => 'example.com/no-scheme'},       $schema, E('/v', 'Does not match uri format.');
  validate_ok {v => 'http://example.com/%z'},       $schema, E('/v', 'Does not match uri format.');
  validate_ok {v => 'http://example.com/%a'},       $schema, E('/v', 'Does not match uri format.');
  validate_ok {v => 'http:////'},                   $schema, E('/v', 'Does not match uri format.');
  validate_ok {v => ''},                            $schema, E('/v', 'Does not match uri format.');
}

{
  local $schema->{properties}{v}{format} = 'unknown';
  validate_ok {v => 'whatever'}, $schema;
}

done_testing;
