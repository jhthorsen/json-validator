package Some;
use Mojo::Base -base;

sub j             { JSON::Validator->new }
sub validate_age0 { shift->j->schema('data:///age0.json')->validate(shift) }
sub validate_age1 { shift->j->schema('data:///age1.json')->validate(shift) }

1;
__DATA__
@@ age0.json
{
  "title": "Some module",
  "type": "object",
  "properties": {
    "age": { "type": "integer", "minimum": 0, "description": "Age in years" }
  }
}
