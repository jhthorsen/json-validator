use Mojo::Base -strict;
use JSON::Validator::Schema::OpenAPIv3;
use Mojo::File;
use Test::More;

my $cwd    = Mojo::File->new(__FILE__)->dirname;
my $schema = JSON::Validator::Schema::OpenAPIv3->new;

is $schema->specification, 'https://spec.openapis.org/oas/3.0/schema/2019-04-02', 'specification';
is_deeply $schema->coerce, {booleans => 1, numbers => 1, strings => 1}, 'default coercion';

note 'jv->schema';
$schema = JSON::Validator->new->schema($cwd->child(qw(spec v3-petstore.json)))->schema;
isa_ok $schema, 'JSON::Validator::Schema::OpenAPIv3';

note 'validate schema';
my @errors = @{JSON::Validator->new->schema({openapi => '3.0.0', paths => {}})->schema->errors};
is "@errors", '/info: Missing property.', 'invalid schema';

done_testing;
