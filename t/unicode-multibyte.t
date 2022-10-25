use lib '.';
use t::Helper;
use Mojo::File 'path';
use Mojo::Util 'encode';
use Test::More;

my $builder = Test::More->builder;
binmode($builder->output, ':encoding(UTF-8)');
binmode($builder->failure_output, ':encoding(UTF-8)');
binmode($builder->todo_output, ':encoding(UTF-8)');

my $perl_utf8_str = "foo\x{2013}bar";
my $encoded_bytes = encode('UTF-8', $perl_utf8_str);
my $json_file = path(__FILE__)->dirname->child('spec')->child('with-unicode-multibyte.json');
my $yaml_file = path(__FILE__)->dirname->child('spec')->child('with-unicode-multibyte.yml');

validate_ok {foo => $perl_utf8_str}, $json_file;
validate_ok {foo => $encoded_bytes}, $json_file, E('/foo', "Not in enum list: $perl_utf8_str.");

validate_ok {foo => $perl_utf8_str}, $yaml_file;
validate_ok {foo => $encoded_bytes}, $yaml_file, E('/foo', "Not in enum list: $perl_utf8_str.");

done_testing;
