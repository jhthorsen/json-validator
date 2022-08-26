use Mojo::Base -strict;
use JSON::Validator::Schema::OpenAPIv2;
use Test::Deep;
use Test::More;

my $schema = JSON::Validator::Schema::OpenAPIv2->new;

$schema->data({
  paths => {
    '/a1'                              => {get    => {}},
    '/a1/bbbbbbb2/{c3}'                => {post   => {}},
    '/a1/bbbbbbbbbbbbbbbbbbbb2/{ccc3}' => {put    => {}},
    '/a1/xxxxxxxxx/{ccc3}'             => {get    => {}},
    '/a1/{b2}/{ccc3}/{d4}'             => {post   => {}},
    '/a1/{bb2}/{c3}/d'                 => {get    => {}},
    '/a1/{bb2}/{ccc3}/{dddd4}/{e5}'    => {put    => {}},
    '/a1/{bbbb2}/{cc3}'                => {get    => {}},
    '/aa1/bbb2/{c3}'                   => {post   => {}},
    '/aaa1/bb2'                        => {get    => {}},
    '/aaa2'                            => {put    => {}},
    '/{aaa1}/{bb2}/{ccc3}'             => {get    => {}},
    '/{x}'                             => {delete => {}},
  },
});

is_deeply(
  $schema->routes->to_array,
  [
    {path => '/a1/{bb2}/{ccc3}/{dddd4}/{e5}',    method => 'put',    operation_id => undef},
    {path => '/a1/{bb2}/{c3}/d',                 method => 'get',    operation_id => undef},
    {path => '/a1/{b2}/{ccc3}/{d4}',             method => 'post',   operation_id => undef},
    {path => '/a1/bbbbbbb2/{c3}',                method => 'post',   operation_id => undef},
    {path => '/a1/bbbbbbbbbbbbbbbbbbbb2/{ccc3}', method => 'put',    operation_id => undef},
    {path => '/a1/xxxxxxxxx/{ccc3}',             method => 'get',    operation_id => undef},
    {path => '/aa1/bbb2/{c3}',                   method => 'post',   operation_id => undef},
    {path => '/a1/{bbbb2}/{cc3}',                method => 'get',    operation_id => undef},
    {path => '/{aaa1}/{bb2}/{ccc3}',             method => 'get',    operation_id => undef},
    {path => '/aaa1/bb2',                        method => 'get',    operation_id => undef},
    {path => '/a1',                              method => 'get',    operation_id => undef},
    {path => '/aaa2',                            method => 'put',    operation_id => undef},
    {path => '/{x}',                             method => 'delete', operation_id => undef},
  ],
  'sorted routes'
) or diag explain $schema->routes->map(sub { $_->{path} })->to_array;

done_testing;
