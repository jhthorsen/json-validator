use Mojo::Base -strict;
use JSON::Validator;
use Mojo::JSON qw(false true);
use Test::More;

# https://github.com/jhthorsen/json-validator/issues/273
# OpenAPI v3.0 uses draft4 semantics, where exclusiveMinimum/exclusiveMaximum
# are booleans modifying minimum/maximum, while OpenAPI v3.1 uses numbers.

my $v30 = JSON::Validator->new->schema(spec(
  '3.0.1',
  {name => 'ex_min', in => 'query', schema => {type => 'number', minimum => 5,  exclusiveMinimum => true}},
  {name => 'in_min', in => 'query', schema => {type => 'number', minimum => 5,  exclusiveMinimum => false}},
  {name => 'ex_max', in => 'query', schema => {type => 'number', maximum => 10, exclusiveMaximum => true}},
))->schema;

is "@{$v30->errors}", '', 'v3.0 spec is valid';

my $ex_min = $v30->get('/paths/~1x/get/parameters/0/schema');
is validate($v30, $ex_min, 5.1), '',                      'boolean exclusiveMinimum=true accepts 5.1';
is validate($v30, $ex_min, 0.5), '/: 0.5 <= minimum(5)',  'boolean exclusiveMinimum=true rejects 0.5';
is validate($v30, $ex_min, 5),   '/: 5 <= minimum(5)',    'boolean exclusiveMinimum=true rejects boundary 5';

my $in_min = $v30->get('/paths/~1x/get/parameters/1/schema');
is validate($v30, $in_min, 5),   '',                      'boolean exclusiveMinimum=false accepts boundary 5';
is validate($v30, $in_min, 4.9), '/: 4.9 < minimum(5)',   'boolean exclusiveMinimum=false rejects 4.9';

my $ex_max = $v30->get('/paths/~1x/get/parameters/2/schema');
is validate($v30, $ex_max, 9.9), '',                      'boolean exclusiveMaximum=true accepts 9.9';
is validate($v30, $ex_max, 2),   '',                      'boolean exclusiveMaximum=true accepts 2';
is validate($v30, $ex_max, 10),  '/: 10 >= maximum(10)',  'boolean exclusiveMaximum=true rejects boundary 10';

# Validation must not autovivify exclusiveMinimum/exclusiveMaximum in the schema
my $plain = {type => 'number', minimum => 1};
is validate($v30, $plain, 2), '', 'plain minimum accepts 2';
ok !exists $plain->{exclusiveMinimum} && !exists $plain->{exclusiveMaximum}, 'schema not modified';

# OpenAPI v3.1 numeric (draft 2019-09 style) values must keep working
my $v31 = JSON::Validator->new->schema(spec(
  '3.1.0',
  {name => 'ex_min', in => 'query', schema => {type => 'number', exclusiveMinimum => 5}},
  {name => 'ex_max', in => 'query', schema => {type => 'number', exclusiveMaximum => 10}},
))->schema;

is "@{$v31->errors}", '', 'v3.1 spec is valid';

my $num_min = $v31->get('/paths/~1x/get/parameters/0/schema');
is validate($v31, $num_min, 5.1), '',                     'numeric exclusiveMinimum accepts 5.1';
is validate($v31, $num_min, 5),   '/: 5 <= minimum(5)',   'numeric exclusiveMinimum rejects boundary 5';

my $num_max = $v31->get('/paths/~1x/get/parameters/1/schema');
is validate($v31, $num_max, 9.9), '',                     'numeric exclusiveMaximum accepts 9.9';
is validate($v31, $num_max, 10),  '/: 10 >= maximum(10)', 'numeric exclusiveMaximum rejects boundary 10';

done_testing;

sub spec {
  my ($version, @parameters) = @_;
  return {
    openapi => $version,
    info    => {title => 'issue-273', version => '1'},
    paths   =>
      {'/x' => {get => {parameters => \@parameters, responses => {200 => {description => 'ok'}}}}},
  };
}

sub validate {
  my ($schema, $sub_schema, $value) = @_;
  return join ', ', $schema->validate($value, $sub_schema);
}
