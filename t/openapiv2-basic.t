use Mojo::Base -strict;
use JSON::Validator::Schema::OpenAPIv2;
use Mojo::File;
use Test::More;

my $cwd    = Mojo::File->new(__FILE__)->dirname;
my $schema = JSON::Validator::Schema::OpenAPIv2->new;

is $schema->specification, 'http://swagger.io/v2/schema.json', 'specification';
is_deeply $schema->coerce, {booleans => 1, numbers => 1, strings => 1}, 'default coercion';

note 'jv->schema';
$schema = JSON::Validator->new->schema($cwd->child(qw(spec v2-petstore.json)))->schema;
isa_ok $schema, 'JSON::Validator::Schema::OpenAPIv2';

note 'validate schema';
@errors = @{JSON::Validator->new->schema({swagger => '2.0', paths => {}})->schema->errors};
is "@errors", '/info: Missing property.', 'invalid schema';

done_testing;
