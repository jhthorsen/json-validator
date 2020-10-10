use Mojo::Base -strict;
use Test::More;
use JSON::Validator::Ref;
use Mojo::JSON qw(false true);

test('without fqn', {foo => 42}, '#bar',  undef);
test('with fqn',    {foo => 42}, '#/bar', 'https://example.com#/bar');
test('false', false, '#/false');
test('true',  false, '#/true');
test('ref hash', false, {'$ref' => '#/true'});

test(
  'ref siblings',
  {'$ref' => '#/inner', b => 2, foo => 44},
  {'$ref' => '#/main',  a => 1, foo => 42},
  undef,
  sub {
    my ($ref, $tied) = @_;
    ok exists $ref->{a}, 'a exists';
    ok exists $ref->{b}, 'b exists';
    is $ref->{a},   1,  'ref a';
    is $ref->{b},   2,  'ref b';
    is $ref->{foo}, 42, 'ref foo';
    is_deeply $tied->schema, {a => 1, b => 2, foo => 42, '$ref' => '#/inner'}, 'schema()';
  }
);

done_testing;

sub test {
  my ($desc, $schema, $ref, $fqn, $cb) = @_;
  my $tied = tie my %ref, 'JSON::Validator::Ref', $schema, $ref, $fqn;

  $ref = {'$ref' => $ref} unless ref $ref eq 'HASH';
  subtest $desc, sub {
    ok exists $ref{'$ref'}, '$ref exists';
    is $tied->ref, $ref->{'$ref'}, 'ref()';
    is $tied->fqn, $fqn || $ref->{'$ref'}, 'fqn()';
    is scalar(%ref), scalar(%$ref), 'scalar';
    is_deeply $tied->schema, $schema, 'schema()' unless $cb;
    is_deeply [sort keys %ref], [sort keys %$ref], 'keys';

    my %kv;
    while (my ($k, $v) = each %ref) { $kv{$k} = $v }
    is_deeply \%kv, $ref, 'each';

    $cb->(\%ref, $tied) if $cb;
  };
}
