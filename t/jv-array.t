use lib '.';
use Mojo::Base -strict;
use Mojo::JSON 'encode_json';
use t::Helper;

my $simple = {type => 'array', items       => {type => 'number'}};
my $length = {type => 'array', minItems    => 2, maxItems => 2};
my $unique = {type => 'array', uniqueItems => 1, items => {type => 'integer'}};
my $tuple = {
  type  => 'array',
  items => [
    {type => 'number'},
    {type => 'string'},
    {type => 'string', enum => ['Street', 'Avenue', 'Boulevard']},
    {type => 'string', enum => ['NW', 'NE', 'SW', 'SE']}
  ]
};

validate_ok [1], $simple;
validate_ok [1, 'foo'], $simple, E('/1', 'Expected number - got string.');
validate_ok [1], $length, E('/', 'Not enough items: 1/2.');
validate_ok [1, 2], $length;
validate_ok [1, 2, 3], $length, E('/', 'Too many items: 3/2.');
validate_ok [123, 124], $unique;
validate_ok [1, 2, 1], $unique, E('/', 'Unique items required.');
validate_ok [1600, 'Pennsylvania', 'Avenue', 'NW'], $tuple;
validate_ok [24, 'Sussex',  'Drive'],  $tuple;
validate_ok [10, 'Downing', 'Street'], $tuple;
validate_ok [1600, 'Pennsylvania', 'Avenue', 'NW', 'Washington'], $tuple;

$tuple->{additionalItems} = Mojo::JSON->false;
validate_ok [1600, 'Pennsylvania', 'Avenue', 'NW', 'Washington'], $tuple,
  E('/', 'Invalid number of items: 5/4.');

validate_ok [1600, 'NW'],
  {type => 'array', contains => {type => 'string', enum => ['NW']}};
validate_ok [1600, 'NW'],
  {type => 'array', contains => {type => 'string', enum => ['Nope']}},
  E('/0', 'Expected string - got number.'), E('/1', 'Not in enum list: Nope.');

# Make sure all similar numbers gets converted from strings
my $jv = JSON::Validator->new->coerce('numbers');
my @numbers;

$jv->schema({type => 'array', items => {type => 'number'}});
@numbers = qw(1.42 2.3 1.42 1.42);
ok !$jv->validate(\@numbers), 'numbers are valid';
is encode_json(\@numbers), encode_json([1.42, 2.3, 1.42, 1.42]),
  'coerced into integers';

$jv->schema({type => 'array', items => {type => 'integer'}});
@numbers = qw(1 2 1 1 3 1);
ok !$jv->validate(\@numbers), 'integers are valid';
is encode_json(\@numbers), encode_json([1, 2, 1, 1, 3, 1]),
  'coerced into numbers';

my $array_constant = {type => 'array', const => [1, 'a', undef]};
validate_ok [1, 'a', undef], $array_constant;
validate_ok [1, 'b', undef], $array_constant,
  E('/', q{Does not match const: [1,"a",null].});

# TODO! true, false are draft 6+ only
validate_ok [1, 'foo', 1.2], {type => 'array', items => {}};
validate_ok [1, 'foo', 1.2], {type => 'array', items => true};

validate_ok [1, 'foo', 1.2], {type => 'array', items => [true, true, false]},
  E('/2', 'Should not match.');

validate_ok [1, 'foo', 1.2], {type => 'array', items => false},
  E('/0', 'Should not match.'), E('/1', 'Should not match.'),
  E('/2', 'Should not match.');

validate_ok [1, 'foo', 1.2],
  {
  definitions => {my_true_ref => true},
  type        => 'array',
  items       => {'$ref' => '#/definitions/my_true_ref'},
  };

validate_ok [1, 'foo', 1.2],
  {
  definitions => {my_false_ref => false},
  type        => 'array',
  items       => {'$ref' => '#/definitions/my_false_ref'},
  },
  E('/0', 'Should not match.'), E('/1', 'Should not match.'),
  E('/2', 'Should not match.');

validate_ok [1, 'foo', 1.2],
  {
  definitions => {my_true_ref => true, my_false_ref => false},
  type        => 'array',
  items       => [
    {'$ref' => '#/definitions/my_true_ref'},
    {'$ref' => '#/definitions/my_true_ref'},
    {'$ref' => '#/definitions/my_false_ref'}
  ],
  },
  E('/2', 'Should not match.');

validate_ok [], {type => 'array', contains => {const => 'foo'}},
  E('/', 'No items contained.');

validate_ok [1], {contains => {const => 'foo'}},
  E('/0', 'Does not match const: "foo".');

validate_ok [1], {items => {not => {}}}, E('/0', 'Should not match.');
validate_ok [1], {items => false}, E('/0', 'Should not match.');

validate_ok [1, 2], {contains => {not => {}}}, E('/0', 'Should not match.'),
  E('/1', 'Should not match.');

validate_ok [1, 2], {contains => false}, E('/0', 'Should not match.'),
  E('/1', 'Should not match.');

validate_ok [1, 'hello'],
  {contains => {const => 1}, items => {type => 'number'}},
  E('/1', 'Expected number - got string.');

validate_ok [1, 'hello'],
  {contains => {const => 1}, items => [{type => 'string'}]},
  E('/0', 'Expected string - got number.');

done_testing;
