use Mojo::Base -strict;
use Mojo::JSON 'false';
use JSON::Validator;
use JSON::Validator::Util
  qw(E data_type schema_type prefix_errors is_type json_pointer);
use Test::More;

my $e = E '/path/x', 'some error';
is "$e", '/path/x: some error', 'E';

is data_type('string'), 'string', 'data_type string';
is data_type(4.2),      'number', 'data_type number';
is data_type(42, [{type => 'integer'}]), 'integer', 'data_type integer';
is data_type([]), 'array', 'data_type array';
is data_type(bless {}, 'other'), 'other', 'data_type other';
is data_type(false), 'boolean', 'data_type boolean';
is data_type(undef), 'null', 'data_type null';
is data_type($e), 'JSON::Validator::Error', 'data_type JSON::Validator::Error';

my $v = JSON::Validator->new;
ok is_type($v,    'JSON::Validator'), 'is_type JSON::Validator';
ok is_type($v,    'Mojo::Base'),      'is_type Mojo::Base';
ok is_type($v,    'HASH'),            'is_type HASH';
ok is_type([],    'ARRAY'),           'is_type ARRAY';
ok is_type({},    'HASH'),            'is_type HASH';
ok is_type(4.2,   'NUM'),             'is_type 4.2';
ok is_type(42,    'NUM'),             'is_type 42';
ok is_type(false, 'BOOL'),            'is_type BOOL';
ok !is_type('2', 'NUM'),  'is_type 2';
ok !is_type(0,   'BOOL'), 'is_type BOOL';

is json_pointer(qw(foo bar)),    'foo/bar',      'json_pointer foo bar';
is json_pointer(qw(f/oo bar)),   'f/oo/bar',     'json_pointer f/oo bar';
is json_pointer(qw(f/oo ~b/ar)), 'f/oo/~0b~1ar', 'json_pointer f/oo ~b/ar';

my $yikes = E {path => '/path/100/y', message => 'yikes'};
is_deeply(
  [map {"$_"} prefix_errors 'allOf', [2, $e], [5, $yikes]],
  ['/path/x: /allOf/2 some error', '/path/100/y: /allOf/5 yikes'],
  'prefix_errors',
);

is schema_type({type => 'integer'}), 'integer', 'schema_type integer';
is schema_type({additionalProperties => {}}), 'object', 'schema_type object';
is schema_type({additionalProperties => {}}, {}), 'object',
  'schema_type object';
is schema_type({additionalProperties => {}}, []), '', 'schema_type not object';
is schema_type({items                => {}}), 'array', 'schema_type array';
is schema_type({items     => {}}, {}), '', 'schema_type not array';
is schema_type({minLength => 4}), 'string', 'schema_type string';
is schema_type({multipleOf => 2}),       'number', 'schema_type number';
is schema_type({const      => 42}),      'const',  'schema_type const';
is schema_type({cannot     => 'guess'}), '',       'schema_type no idea';

done_testing;
