package Some::Module;
use Mojo::Base 'Some';

sub validate_age0 { shift->j->schema('data:///age0.json')->validate(shift) }
sub validate_age1 { shift->j->schema('data://Some::Module/age1.json')->validate(shift) }

1;
__DATA__
@@ age1.json
{
  "title": "Some module",
  "type": "object",
  "properties": {
    "age": { "type": "integer", "minimum": 1, "description": "Age in years" }
  }
}
