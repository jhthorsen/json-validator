use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use JSON::Validator 'validate_json';

my $data = {};
$data->{rec} = $data;

$SIG{ALRM} = sub { die 'Recursion!' };
alarm 2;
my @errors = ('i_will_be_removed');
eval { @errors = validate_json {top => $data}, 'data://main/spec.json' };
is $@, '', 'no error';
is_deeply(\@errors, [], 'avoided recursion');

done_testing;
__DATA__
@@ spec.json
{
  "properties": {
    "top": { "$ref": "#/definitions/again" }
  },
  "definitions": {
    "again": {
      "anyOf": [
        {"type": "string"},
        {
          "type": "object",
          "properties": {
            "rec": {"$ref": "#/definitions/again"}
          }
        }
      ]
    }
  }
}
