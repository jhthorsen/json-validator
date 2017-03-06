use lib '.';
use t::Helper;

my $validator = JSON::Validator->new;
my $schema = {anyOf => [{type => "string", maxLength => 5}, {type => "number", minimum => 0}]};

validate_ok 'short',    $schema;
validate_ok 'too long', $schema, E('/', 'anyOf failed: String is too long: 8/5.');
validate_ok 12,         $schema;
validate_ok - 1, $schema, E('/', 'anyOf failed: -1 < minimum(0)');
validate_ok {}, $schema, E('/', 'anyOf failed: Expected string or number, got object.');

# anyOf with explicit integer (where _guess_data_type returns 'number')
my $schemaB = {anyOf => [{type => "integer"}, {minimum => 2}]};
validate_ok 1, $schemaB;

validate_ok(
  {type => 'string'},
  {
    properties => {
      type => {
        anyOf => [
          {'$ref' => '#/definitions/simpleTypes'},
          {
            type        => 'array',
            items       => {'$ref' => '#/definitions/simpleTypes'},
            minItems    => 1,
            uniqueItems => Mojo::JSON::true,
          }
        ]
      },
    },
    definitions => {simpleTypes => {enum => [qw(array boolean integer null number object string)]}}
  }
);

validate_ok(
  {age => 6},
  {
    '$schema'   => 'http://json-schema.org/draft-04/schema#',
    type        => 'object',
    title       => 'test',
    description => 'test',
    properties  => {age => {type => 'number', anyOf => [{multipleOf => 5}, {multipleOf => 3}]}}
  }
);

done_testing;
