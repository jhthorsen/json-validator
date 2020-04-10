use Mojo::Base -strict;
use JSON::Validator;
use Test::More;

my $spec = Mojo::File::path(qw(t spec person.json))->to_abs;
my $jv   = JSON::Validator->new;

note "file://$spec";
ok eval { $jv->schema("file://$spec") }, 'loaded from file://';
isa_ok($jv->schema, 'JSON::Validator::Schema');
is $jv->schema->get('/title'), 'Example Schema', 'got example schema';

done_testing;
