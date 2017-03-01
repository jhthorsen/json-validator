use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $should_fail = JSON::Validator->new->schema('data://main/should_fail.json');
my $json_schema = JSON::Validator->new->schema('http://json-schema.org/draft-04/schema#');
my @errors;

# The schema is invalid...
@errors = $json_schema->validate($should_fail->schema->data);
is $errors[0], '/properties/should_fail: Expected object - got array.', 'invalid property element';

# ...but can still be used to validate data.
@errors = $should_fail->validate({foo => 123});
is int(@errors), 0, 'data is valid';

done_testing;

__DATA__
@@ should_fail.json
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "title": "Example Schema That Should Fail To Load",
  "description": "There is an array as the value of an object property, which should not be allowed.",
  "type": "object",
  "properties": {
    "foo": { "type": "integer" },
    "should_fail": []
  }
}
