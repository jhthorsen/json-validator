use lib '.';
use t::Helper;
use Mojo::Util 'decode';

my $schema = {type => 'object', properties => {v => {type => 'string'}}};

subtest 'byte' => sub {
  local $schema->{properties}{v}{format} = 'byte';
  validate_ok {v => 'amh0aG9yc2Vu'}, $schema;
  validate_ok {v => "\0"}, $schema, E('/v', 'Does not match byte format.');
};

subtest 'date' => sub {
  local $schema->{properties}{v}{format} = 'date';
  validate_ok {v => '2014-12-09'},           $schema;
  validate_ok {v => '0000-00-00'},           $schema, E('/v', 'Month out of range.');
  validate_ok {v => '0000-01-00'},           $schema, E('/v', 'Day out of range.');
  validate_ok {v => '2014-12-09T20:49:37Z'}, $schema, E('/v', 'Does not match date format.');
  validate_ok {v => '0-0-0'},                $schema, E('/v', 'Does not match date format.');
  validate_ok {v => '09-12-2014'},           $schema, E('/v', 'Does not match date format.');
  validate_ok {v => '09-DEC-2014'},          $schema, E('/v', 'Does not match date format.');
  validate_ok {v => '09/12/2014'},           $schema, E('/v', 'Does not match date format.');
};

subtest 'date-time' => sub {
  local $schema->{properties}{v}{format} = 'date-time';

  validate_ok {v => $_}, $schema
    for ('2017-03-29T23:02:55.831Z', '2017-03-29t23:02:55.01z', '2017-03-29 23:02:55-12:00',
    '2016-02-29T23:02:55+05:00', '2006-01-02 15:04:05+23:59', '2006-01-02 15:04:05-23:59');

  validate_ok {v => "2017-03-29\t23:02:55-12:00"},  $schema, E('/v', 'Does not match date-time format.');
  validate_ok {v => '2017-03-29T23:02:55+0:0'},     $schema, E('/v', 'Does not match date-time format.');
  validate_ok {v => '2017-03-29T23:02:55+123:00'},  $schema, E('/v', 'Does not match date-time format.');
  validate_ok {v => '2017-03-29\t23:02:55+0:0'},    $schema, E('/v', 'Does not match date-time format.');
  validate_ok {v => '2017-03-29\t23:02:55+123:00'}, $schema, E('/v', 'Does not match date-time format.');
  validate_ok {v => '2017-03-29\t23:02:55-12'},     $schema, E('/v', 'Does not match date-time format.');
  validate_ok {v => '2017-03-29\t23:02:55-12:00'},  $schema, E('/v', 'Does not match date-time format.');
  validate_ok {v => '2017-03-29T23:02:55-12'},      $schema, E('/v', 'Does not match date-time format.');
  validate_ok {v => 'xxxx-xx-xxtxx:xx:xxz'},        $schema, E('/v', 'Does not match date-time format.');

  validate_ok {v => '2017-03-29T23:02:60Z'},        $schema, E('/v', 'Second out of range.');
  validate_ok {v => '2017-03-29T23:61:55Z'},        $schema, E('/v', 'Minute out of range.');
  validate_ok {v => '2017-03-29T24:02:55Z'},        $schema, E('/v', 'Hour out of range.');
  validate_ok {v => '2017-03-32T23:02:55Z'},        $schema, E('/v', 'Day out of range.');
  validate_ok {v => '2017-02-29T23:02:55Z'},        $schema, E('/v', 'Day out of range.');
  validate_ok {v => '2017-02-30T23:02:55Z'},        $schema, E('/v', 'Day out of range.');
  validate_ok {v => '2017-03-00T23:02:55Z'},        $schema, E('/v', 'Day out of range.');
  validate_ok {v => '2017-00-29T23:02:55Z'},        $schema, E('/v', 'Month out of range.');
  validate_ok {v => '2017-13-29T23:02:55Z'},        $schema, E('/v', 'Month out of range.');

  validate_ok {v => '2017-03-29T23:02:55+23:60'},   $schema, E('/v', 'Time offset minute out of range.');
  validate_ok {v => '2017-03-29T23:02:55+24:00'},   $schema, E('/v', 'Time offset hour out of range.');
};

subtest 'double' => sub {
  local $schema->{properties}{v}{format} = 'double';
  local $TODO = 'cannot test double, since input is already rounded';
  validate_ok {v => '1.1000000238418599085576943252817727625370025634765626'}, $schema;
};

subtest 'duration' => sub {
  local $schema->{properties}{v}{format} = 'duration';
  validate_ok {v => 'foo'},              $schema, E('/v', 'Does not match duration format.');
  validate_ok {v => 'P4Y'},              $schema;
  validate_ok {v => 'PT0S'},             $schema;
  validate_ok {v => 'P1M'},              $schema;
  validate_ok {v => 'PT1M'},             $schema;
  validate_ok {v => 'PT0.5M'},           $schema;
  validate_ok {v => 'PT0,5M'},           $schema;
  validate_ok {v => 'P23DT23H'},         $schema;
  validate_ok {v => 'P3Y6M4DT12H30M5S'}, $schema;
};

subtest 'email' => sub {
  local $schema->{properties}{v}{format} = 'email';
  validate_ok {v => 'jhthorsen@cpan.org'}, $schema;
  validate_ok {v => 'foo'},                $schema, E('/v', 'Does not match email format.');
  validate_ok {v => '用户@例子.广告'},           $schema, E('/v', 'Does not match email format.');
};

subtest 'float' => sub {
  local $schema->{properties}{v}{format} = 'float';
  validate_ok {v => '-1.10000002384186'}, $schema;
  validate_ok {v => '1.10000002384186'},  $schema;
};

subtest 'int32' => sub {
  local $schema->{properties}{v}{format} = 'int32';
  validate_ok {v => '-2147483648'}, $schema;
  validate_ok {v => '2147483647'},  $schema;
  validate_ok {v => '2147483648'},  $schema, E('/v', 'Does not match int32 format.');
};

subtest 'int64' => sub {
  local $schema->{properties}{v}{format} = 'int64';
  local $TODO = 'Not a 64 bit Perl' unless JSON::Validator::Formats::IV_SIZE >= 8;
  validate_ok {v => '-9223372036854775808'}, $schema;
  validate_ok {v => '9223372036854775807'},  $schema;
  validate_ok {v => '9223372036854775808'},  $schema, E('/v', 'Does not match int64 format.');
};

subtest 'hostname' => sub {
  local $TODO = eval 'require Data::Validate::Domain;1' ? undef : 'Missing module';
  local $schema->{properties}{v}{format} = 'hostname';
  validate_ok {v => 'mojolicio.us'}, $schema;
  validate_ok {v => '[]'}, $schema, E('/v', 'Does not match hostname format.');
};

subtest 'idn-email' => sub {
  validate_ok {v => decode('UTF-8', '用户@例子.广告')}, $schema;
  local $TODO = eval 'require Net::IDN::Encode;1' ? undef : 'Missing module';
  local $schema->{properties}{v}{format} = 'idn-email';
  validate_ok {v => decode('UTF-8', '用户@')}, $schema, E('/v', 'Does not match idn-email format.');
};

subtest 'idn-hostname' => sub {
  local $schema->{properties}{v}{format} = 'idn-hostname';
  validate_ok {v => decode('UTF-8', '例子.广告')}, $schema;
};

subtest 'iri' => sub {
  local $schema->{properties}{v}{format} = 'iri';
  validate_ok {v => 'http://mojolicio.us/?ø=123'}, $schema;
  validate_ok {v => decode('UTF-8', 'https://例子.广告/Ῥόδος')}, $schema;
  validate_ok {v => '/Ῥόδος'}, $schema, E('/v', 'Scheme missing.');
};

subtest 'iri-reference' => sub {
  local $schema->{properties}{v}{format} = 'iri-reference';
  validate_ok {v => '/Ῥόδος'},        $schema;
  validate_ok {v => 'Ῥόδος'},         $schema;
  validate_ok {v => 'http:///Ῥόδος'}, $schema,;
};

subtest 'ipv4' => sub {
  local $TODO = eval 'require Data::Validate::IP;1' ? undef : 'Missing module';
  local $schema->{properties}{v}{format} = 'ipv4';
  validate_ok {v => '255.100.30.1'}, $schema;
  validate_ok {v => '300.0.0.0'}, $schema, E('/v', 'Does not match ipv4 format.');
};

subtest 'ipv6' => sub {
  local $TODO = eval 'require Data::Validate::IP;1' ? undef : 'Missing module';
  local $schema->{properties}{v}{format} = 'ipv6';
  validate_ok {v => '::1'}, $schema;
  validate_ok {v => '300.0.0.0'}, $schema, E('/v', 'Does not match ipv6 format.');
};

subtest 'json-pointer' => sub {
  local $schema->{properties}{v}{format} = 'json-pointer';
  validate_ok {v => ''},         $schema;
  validate_ok {v => '/foo/bar'}, $schema;
  validate_ok {v => 'foo/bar'},  $schema, E('/v', 'Does not match json-pointer format.');
};

subtest 'regex' => sub {
  local $schema->{properties}{v}{format} = 'regex';
  validate_ok {v => '(\w+)'}, $schema;
  validate_ok {v => '(\w'}, $schema, E('/v', 'Does not match regex format.');
};

subtest 'relative-json-pointer' => sub {
  local $schema->{properties}{v}{format} = 'relative-json-pointer';
  validate_ok {v => '0'},           $schema;
  validate_ok {v => '42#'},         $schema;
  validate_ok {v => '100/foo/bar'}, $schema;
  validate_ok {v => '#'},           $schema, E('/v', 'Relative JSON Pointer must start with a non-negative-integer.');
  validate_ok {v => '42foo/bar'},   $schema, E('/v', 'Does not match relative-json-pointer format.');
};

subtest 'time' => sub {
  local $schema->{properties}{v}{format} = 'time';
  validate_ok {v => $_}, $schema for qw(23:02:55.831Z 23:02:55.01z 23:02:55-12:00 23:02:55+05:00);
  validate_ok {v => 'xx:xx:xxz'}, $schema, E('/v', 'Does not match time format.');
  validate_ok {v => '23:02:60Z'}, $schema, E('/v', 'Second out of range.');
  validate_ok {v => '23:61:55Z'}, $schema, E('/v', 'Minute out of range.');
  validate_ok {v => '24:02:55Z'}, $schema, E('/v', 'Hour out of range.');
};

subtest 'uri' => sub {
  local $schema->{properties}{v}{format} = 'uri';
  validate_ok {v => '//example.com/no-scheme'},    $schema, E('/v', 'Scheme missing.');
  validate_ok {v => ''},                           $schema, E('/v', 'Scheme, path or fragment are required.');
  validate_ok {v => '0://mojolicio.us/?x=123'},    $schema, E('/v', 'Scheme must begin with a letter.');
  validate_ok {v => 'http://example.com/%z'},      $schema, E('/v', 'Invalid hex escape.');
  validate_ok {v => 'http://example.com/%a'},      $schema, E('/v', 'Hex escapes are not complete.');
  validate_ok {v => 'http:////'},                  $schema, E('/v', 'Path cannot not start with //.');
  validate_ok {v => 'http://mojolicio.us/?x=123'}, $schema;
  validate_ok {v => '/relative-path'},             $schema;
  validate_ok {v => 'relative-path'},              $schema;
};

subtest 'uri-reference' => sub {
  local $schema->{properties}{v}{format} = 'uri-reference';
  validate_ok {v => 'http:///whatever'}, $schema;
  validate_ok {v => '/relative-path'},   $schema;
  validate_ok {v => 'relative-path'},    $schema;
};

subtest 'uri-template' => sub {
  local $schema->{properties}{v}{format} = 'uri-template';
  validate_ok {v => 'http://mojolicio.us/?x={x}'}, $schema;
};

subtest 'unknown' => sub {
  my $warn = 'no warnings seen';
  local $SIG{__WARN__} = sub { $warn = shift };
  local $schema->{properties}{v}{format} = 'unknown';
  validate_ok {v => 'whatever'}, $schema;
  like $warn, qr{Format rule for 'unknown' is missing}, 'unknown format cause a warning';
};

subtest 'uuid' => sub {
  local $schema->{properties}{v}{format} = 'uuid';
  validate_ok {v => '5782165B-6BB6-A72F-B3DD-369D707D6C72'}, $schema, E('/v', 'Does not match uuid format.');
  validate_ok {v => '5782165B-6BB6-472F-B3DD-369D707D6C72'}, $schema;
};

done_testing;
