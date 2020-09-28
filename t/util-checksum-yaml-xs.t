BEGIN {
  unshift @INC, sub {
    my $file = $_[1];
    die "Skipping $file in this test" if $file =~ m!Sereal\W+Encoder\.pm$!;
  };
}

use Mojo::Util 'md5_sum';
use JSON::Validator;
use JSON::Validator::Util qw(data_checksum);
use Test::More;

my $d_hash  = {foo => {}, bar => {}};
my $d_hash2 = {bar => {}, foo => {}};
my $d_undef = {foo => undef};
my $d_obj   = {foo => JSON::Validator::Error->new};
my $d_array  = ['foo', 'bar'];
my $d_array2 = ['bar', 'foo'];

ok !$INC{'Sereal/Encoder.pm'}, 'Sereal::Encoder was not loaded';

isnt data_checksum($d_array), data_checksum($d_array2), 'data_checksum array';
is data_checksum($d_hash),    data_checksum($d_hash2),  'data_checksum hash field order';
isnt data_checksum($d_hash),  data_checksum($d_undef),  'data_checksum hash not undef';
isnt data_checksum($d_hash),  data_checksum($d_obj),    'data_checksum hash not object';
isnt data_checksum($d_obj),   data_checksum($d_undef),  'data_checksum object not undef';
isnt data_checksum(3.14), md5_sum(3.15),         'data_checksum numeric';
is data_checksum(3.14),   data_checksum('3.14'), 'data_checksum numeric like string';

done_testing;
