use lib '.';
use t::Helper;

my $missing = E '/required', '/allOf/0 Missing property.';
my $schema  = {type => 'object', allOf => [{required => ['required']}]};
my @tests   = (
  [{foo => 1, required  => 2}, $schema],
  [{foo => 2, forbidden => 3}, $schema, $missing],
  [{foo => 3, forbidden => 3, required => 2}, $schema],
  [{foo => 4}, $schema, $missing]
);

subtest 'property "required" must be present' => sub {
  validate_ok @$_ for @tests;
};

subtest 'Property "forbidden" must not be present' => sub {
  $schema->{not} = {required => ['forbidden']};
  splice @{$tests[1]}, 2, 0, E '/', 'Should not match.';
  $tests[2][2] = E '/', 'Should not match.';
  validate_ok @$_ for @tests;
};

subtest 'Move "not" constraint to "allOf"' => sub {
  push @{$schema->{allOf}}, {not => delete $schema->{not}};
  $tests[1][2] = $tests[2][2] = E '/', '/allOf/1 Should not match.';
  $tests[1][3] = $missing;
  validate_ok @$_ for @tests;
};

done_testing;
