use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use JSON::Validator::OpenAPI::Mojolicious;

my $openapi = JSON::Validator::OpenAPI::Mojolicious->new;
my ($schema, @errors);

# standard
$schema = {type => 'object', properties => {age => {type => 'integer'}}};
@errors = $openapi->validate_input({age => '42'}, $schema);
like "@errors", qr{Expected integer - got string}, 'string != integer';

# readOnly
$schema->{properties}{age}{readOnly} = Mojo::JSON->true;
@errors = $openapi->validate_input({age => 42}, $schema);
is "@errors", '/age: Read-only.', 'age is ro';

$schema->{required} = ['age'];
@errors = $openapi->validate_input({no_age => 42}, $schema);
is "@errors", '', 'age is readOnly, so not required in input';

@errors = $openapi->validate({no_age => 42}, $schema);
is "@errors", '/age: Missing property.', 'age is missing in output';

# collectionFormat
$schema = {type => 'array', items => {collectionFormat => 'csv', type => 'integer'}};
@errors = $openapi->validate_input('1,2,3', $schema);
is "@errors", '', 'csv data';

# file
$schema = {type => 'file', required => Mojo::JSON->true};
@errors = $openapi->validate_input(undef, $schema);
like "@errors", qr{Missing property}, 'file';

# discriminator
$openapi->schema({
  definitions => {
    Cat => {
      type       => 'object',
      required   => ['huntingSkill'],
      properties => {
        huntingSkill => {
          default => 'lazy',
          enum    => ['clueless', 'lazy', 'adventurous', 'aggressive'],
          type    => 'string',
        }
      }
    }
  }
});
$schema = {
  discriminator => 'petType',
  properties    => {petType => {'type' => 'string'}},
  required      => ['petType'],
  type          => 'object',
};
@errors = $openapi->validate_input({}, $schema);
is "@errors", "/: Discriminator petType has no value.", "petType has no value";

@errors = $openapi->validate_input({petType => 'Bat'}, $schema);
is "@errors", "/: No definition for discriminator Bat.", "no definition for discriminator";

@errors = $openapi->validate_input({petType => 'Cat'}, $schema);
is "@errors", "/huntingSkill: Missing property.", "missing property";

diag join ',', @errors;

done_testing;
