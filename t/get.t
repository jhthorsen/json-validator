use Mojo::Base -strict;
use JSON::Validator::Schema::Draft201909;
use Test::More;

my $jv;

subtest 'setup' => sub {
  $jv = JSON::Validator::Schema::Draft201909->new({
    '$defs'    => {z1 => {'$ref' => '#/$defs/z2', minLength => 1}, z2 => {type => 'string'}},
    properties => {
      bar    => {items => [{properties => {y => {'$ref' => '#/$defs/z1'}, x => {type => 'integer'}}}]},
      foo    => {items => [{properties => {y => {type   => 'string'}}}]},
      'x/~y' => {type  => 'boolean'},
    },
  });

  ok !$jv->is_invalid, 'schema is valid' or diag explain $jv->errors;
};

subtest 'get($string)' => sub {
  is $jv->get('/properties/foo/items/0/properties/y/type'), 'string',  'get /properties/foo/items/0/properties/y/type';
  is $jv->get('/$defs/baz'),                                undef,     'get /$defs/baz';
  is $jv->get('/properties/baz'),                           undef,     'get /properties/baz';
  is $jv->get('/properties/baz'),                           undef,     'get /properties/baz';
  is $jv->get('/properties/x~1~0y/type'),                   'boolean', 'get /x~1y';
};

subtest 'get(\@array)' => sub {
  is $jv->get([qw(properties foo items 0 properties y type)]), 'string',
    'get /properties/foo/items/0/properties/y/type';
  is $jv->get([qw($defs baz)]),            undef,     'get /$defs/baz';
  is $jv->get([qw(properties baz)]),       undef,     'get /properties/baz';
  is $jv->get([qw(properties x/~y type)]), 'boolean', 'get /properties/x/~y type';
};

subtest '$ref' => sub {
  is_deeply $jv->get('/properties/bar/items/0/properties/y'), {minLength => 1, type => 'string'},
    'get /bar/items/0/properties/y';
  is $jv->get('/properties/bar/items/0/properties/y/$ref'), '#/$defs/z1', 'get /bar/items/0/properties/y/$ref';
  is_deeply $jv->get('/properties/bar/items/0/properties'), {y => {'$ref' => '#/$defs/z1'}, x => {type => 'integer'}},
    'get /bar/items/0/properties';
};

subtest 'callback' => sub {
  my @res;
  $jv->get(['properties', undef, 'items', '0', 'properties', undef, 'type'], sub { push @res, [@_] });
  is @res, 3, 'callback called';
  is_deeply \@res,
    [
    ['integer', '/properties/bar/items/0/properties/x/type'],
    ['string',  '/properties/bar/items/0/properties/y/type'],
    ['string',  '/properties/foo/items/0/properties/y/type'],
    ],
    'callback data';
};

subtest 'collection' => sub {
  note 'This is not officially supported. I think the callback version is the way to go.';
  is_deeply $jv->get(['properties', 'bar', 'items', '0', 'properties', undef, 'type']), ['integer', 'string'],
    'one level';
  my $c = $jv->get(['properties', undef, 'items', '0', 'properties', undef, 'type']);
  is $c->first->first, 'integer', 'collections of collections';
  is_deeply $c->flatten->to_array, ['integer', 'string', 'string', undef], 'flatten' or diag explain $c;
};

done_testing;
