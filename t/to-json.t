use Mojo::Base -strict;
use Test::More;
use JSON::Validator 'validate_json';

my @errors = validate_json(bless({path => '', message => 'yikes'}, 'JSON::Validator::Error'), 'data://main/spec.json');

ok !@errors, 'TO_JSON on objects' or diag join ', ', @errors;

done_testing;
__DATA__
@@ spec.json
{
  "type": "object",
  "properties": { "message": { "type": "string" } },
  "required": ["message"]
}
