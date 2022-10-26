use lib '.';
use t::Helper;
use Mojo::File qw(path);
use Mojo::Util qw(encode);
use Test::More;

my $json_file = path(__FILE__)->dirname->child('spec')->child('with-unicode-multibyte.json');
my $yaml_file = path(__FILE__)->dirname->child('spec')->child('with-unicode-multibyte.yml');

my $perl_utf8_str = "foo\x{266b}bar";
my $encoded_bytes = encode('UTF-8', $perl_utf8_str);
my $with_replacement_char = "replacement\x{fffd}char";
my $invalid_utf8_1 = "replacement\x{d800}char";
my $invalid_utf8_2 = "replacement\x{d8f0}char";

validate_ok {foo => $perl_utf8_str}, $json_file;
validate_ok {foo => $encoded_bytes}, $json_file, E('/foo', "Not in enum list: $perl_utf8_str.");

validate_ok {foo => $perl_utf8_str}, $yaml_file;
validate_ok {foo => $encoded_bytes}, $yaml_file, E('/foo', "Not in enum list: $perl_utf8_str.");

validate_ok {bar => $with_replacement_char}, $json_file;
validate_ok {bar => $invalid_utf8_1}, $json_file, E('/bar', "Not in enum list: $with_replacement_char.");
validate_ok {bar => $invalid_utf8_2}, $json_file, E('/bar', "Not in enum list: $with_replacement_char.");

done_testing;
