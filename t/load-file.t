use Mojo::Base -strict;
use JSON::Validator;
use Test::More;

my $spec = Mojo::URL->new->scheme('file')->host('')->path(Mojo::File::path(qw(t spec person.json))->to_abs);
my $jv   = JSON::Validator->new;

note $spec->to_string;
ok eval { $jv->schema($spec->to_string) }, 'loaded from file://' or diag $@;
isa_ok $jv->schema, 'JSON::Validator::Schema';
is $jv->schema->get('/title'), 'Example Schema', 'got example schema';
is $jv->schema->id, $spec->to_string, 'schema id';
is_deeply [sort keys %{$jv->{schemas}}], [$jv->schema->id], 'schemas in store';

ok eval { $jv->schema($spec->to_string) }, 'loaded from file:// again' or diag $@;
is $jv->schema->id, $spec->to_string, 'schema id again';
is_deeply [sort keys %{$jv->{schemas}}], [$jv->schema->id], 'schemas in store again';

done_testing;
