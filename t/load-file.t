use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $spec      = Mojo::File::path(qw(t spec person.json))->to_abs;
my $validator = JSON::Validator->new;

note "file://$spec";
ok eval { $validator->schema("file://$spec") }, 'loaded from file://';
isa_ok($validator->schema, 'Mojo::JSON::Pointer');
is $validator->schema->get('/title'), 'Example Schema', 'got example schema';

done_testing;
