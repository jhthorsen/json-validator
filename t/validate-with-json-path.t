use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new->schema('data://main/sub-schema.json');
my (@errors, %data);

@errors = $validator->validate({x => 42}, '/foo#bar');
is "@errors", "/: Expected string - got object.", "not a string";

@errors = $validator->validate({x => 42}, '/foo#baz');
is "@errors", "", "is an object";

done_testing;

__DATA__
@@ sub-schema.json
{
  "foo#bar": {"type": "string"},
  "foo#baz": {"type": "object"}
}
