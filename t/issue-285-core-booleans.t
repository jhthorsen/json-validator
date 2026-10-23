use Mojo::Base -strict;
use JSON::Validator;
use JSON::Validator::Util qw(data_checksum);
use Mojo::JSON            qw(false true);
use Test::More;

plan skip_all => 'Perl has no core booleans' unless defined &builtin::is_bool;

BEGIN { warnings->unimport('experimental::builtin') if defined &builtin::is_bool }
my ($core_true, $core_false) = (builtin::true(), builtin::false());

is data_checksum($core_true),   data_checksum(true),  'a core true has the checksum of a JSON true';
is data_checksum($core_false),  data_checksum(false), 'a core false has the checksum of a JSON false';
isnt data_checksum($core_true), data_checksum(1),     'but not the checksum of the number 1';
isnt data_checksum($core_true), data_checksum('1'),   'or of the string "1"';

my $jv = JSON::Validator->new;

$jv->schema({type => 'object', properties => {v => {type => 'boolean', const => $core_true}}});
is_deeply [map {"$_"} $jv->validate({v => $core_true})],  [], 'const of a core true takes a core true';
is_deeply [map {"$_"} $jv->validate({v => true})],        [], 'and a JSON true';
is_deeply [map {"$_"} $jv->validate({v => $core_false})], ['/v: Does not match const: true.'], 'and not a core false';

$jv->schema({type => 'object', properties => {v => {enum => [$core_true]}}});
is_deeply [map {"$_"} $jv->validate({v => true})], [], 'enum of a core true takes a JSON true';

$jv->schema({type => 'object', properties => {v => {enum => [true]}}});
is_deeply [map {"$_"} $jv->validate({v => $core_true})], [], 'and enum of a JSON true takes a core true';

$jv = JSON::Validator->new->coerce('booleans');
$jv->schema({type => 'object', properties => {v => {type => 'boolean', const => $core_true}}});
is_deeply [map {"$_"} $jv->validate({v => 1})], [], 'a 1 coerced to a boolean matches const of a core true';

done_testing;
