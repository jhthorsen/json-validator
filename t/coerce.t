use Mojo::Base -strict;
use JSON::Validator;
use Mojo::JSON 'to_json';
use Test::More;

my $jv     = JSON::Validator->new;
my %coerce = (booleans => 1);
is_deeply($jv->coerce(%coerce)->coerce, {booleans => 1}, 'hash is accepted');
is_deeply(
  $jv->coerce(\%coerce)->coerce,
  {booleans => 1},
  'hash reference is accepted'
);

note
  'coerce(1) is here for back compat reasons, even though not documented any more';
is_deeply(
  $jv->coerce(1)->coerce,
  {%coerce, numbers => 1, strings => 1},
  '1 is accepted'
);

note 'make sure input is coerced';
my @items = ([boolean => 'true'], [integer => '42'], [number => '4.2']);
for my $i (@items) {
  for my $schema (schemas($i->[0])) {
    my $x = $i->[1];
    $jv->validate($x, $schema);
    is to_json($x), $i->[1], sprintf 'no quotes around %s %s', $i->[0],
      to_json($schema);

    $x = {v => $i->[1]};
    $jv->validate($x, {type => 'object', properties => {v => $schema}});
    is to_json($x->{v}), $i->[1], sprintf 'no quotes around %s %s', $i->[0],
      to_json($schema);

    $x = [$i->[1]];
    $jv->validate($x, {type => 'array', items => $schema});
    is to_json($x->[0]), $i->[1], sprintf 'no quotes around %s %s', $i->[0],
      to_json($schema);
  }
}

done_testing;

sub schemas {
  my $base = {type => shift};
  return (
    $base,
    {type  => ['array', $base->{type}]},
    {allOf => [$base]},
    {anyOf => [{type => 'array'}, $base]},
    {oneOf => [$base, {type => 'array'}]},
  );
}
