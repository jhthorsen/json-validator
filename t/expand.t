use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Swagger2;

my $original = Swagger2->new;
my $expanded;

$original->load('t/data/petstore.json');
$expanded = $original->expand;

#diag Data::Dumper::Dumper($expanded->tree->data);

is_deeply(
  $original->tree->get('/paths/~1pets/get/responses/200/schema/items'),
  {'$ref' => '#/definitions/Pet'},
  'original /paths/~1pets/get/responses/200/schema/items'
);

is_deeply(
  $expanded->tree->get('/paths/~1pets/get/responses/200/schema/items'),
  {
    required => ["id", "name"],
    properties => {id => {type => "integer", format => "int64"}, name => {type => "string"}, tag => {type => "string"}}
  },
  'expanded /paths/~1pets/get/responses/200/schema/items'
);

ok find_key($original->tree->data, '$ref'), '$ref in original';
ok !find_key($expanded->tree->data, '$ref'), 'no $ref in expanded';

done_testing;

sub find_key {
  my ($data, $needle) = @_;

  for my $k (keys %$data) {
    return 1 if $k eq $needle;
    return 1 if ref $data->{$k} eq 'HASH' and find_key($data->{$k}, $needle);
  }

  return 0;
}
