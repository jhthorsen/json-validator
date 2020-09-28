use Mojo::Base -strict;
use Test::More;

BEGIN { use_ok('JSON::Validator::Formats'); }

note 'byte';
is JSON::Validator::Formats::check_byte('amh0aG9yc2Vu'), undef,                         'byte amh0aG9yc2Vu';
is JSON::Validator::Formats::check_byte("\0"),           'Does not match byte format.', 'byte null';

note 'date';
is JSON::Validator::Formats::check_date('2019-06-11'), undef,                 'date 2019-06-11';
is JSON::Validator::Formats::check_date('0000-00-00'), 'Month out of range.', 'date 0000-00-00';
is JSON::Validator::Formats::check_date('0000-01-00'), 'Day out of range.',   'date 0000-01-00';
is JSON::Validator::Formats::check_date('2014-12-09T20:49:37Z'), 'Does not match date format.',
  'date 2014-12-09T20:49:37Z';
is JSON::Validator::Formats::check_date('1-1-1'),       'Does not match date format.', 'date 1-1-1';
is JSON::Validator::Formats::check_date('09-12-2014'),  'Does not match date format.', 'date 09-12-2014';
is JSON::Validator::Formats::check_date('2014-DEC-09'), 'Does not match date format.', 'date 2014-DEC-09';
is JSON::Validator::Formats::check_date('2014/04/09'),  'Does not match date format.', 'date 2014/04/09';

{
  note 'double';
  local $TODO = 'cannot test double, since input is already rounded';
  is JSON::Validator::Formats::check_double('1.1000000238418599085576943252817727625370025634765626'), undef, 'double';
}

note 'email';
is JSON::Validator::Formats::check_email('doe@example.org'), undef,                          'email doe@example.org';
is JSON::Validator::Formats::check_email('doe'),             'Does not match email format.', 'email doe';

note 'float';
is JSON::Validator::Formats::check_float(-1.10000002384186), undef, 'float -1.10000002384186';
is JSON::Validator::Formats::check_float(1.10000002384186),  undef, 'float 1.10000002384186';

note 'int32';
is JSON::Validator::Formats::check_int32(-2147483648), undef,                          'int32 -2147483648';
is JSON::Validator::Formats::check_int32(2147483647),  undef,                          'int32 2147483647';
is JSON::Validator::Formats::check_int32(2147483648),  'Does not match int32 format.', 'int32 2147483648';

SKIP: {
  note 'int64';
  skip 'Not a 64 bit Perl' unless JSON::Validator::Formats::IV_SIZE >= 8;
  is JSON::Validator::Formats::check_int64(-9223372036854775808), undef, 'int64 -9223372036854775808';
  is JSON::Validator::Formats::check_int64(9223372036854775807),  undef, 'int64 9223372036854775807';
  is JSON::Validator::Formats::check_int64(9223372036854775808),  'Does not match int64 format.',
    'int64 9223372036854775808';
}

note 'time';
is JSON::Validator::Formats::check_time($_), undef, "time $_"
  for qw(23:02:55.831Z 23:02:55.01z 23:02:55-12:00 23:02:55+05:00);

done_testing;
