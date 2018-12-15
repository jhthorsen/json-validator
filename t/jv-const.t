use lib '.';
use t::Helper;

my $faithful = {
  type       => 'object',
  properties => {constancy => {const => "as the northern star"}}
};
my $ambitious = {
  type => 'object',
  properties =>
    {constancy => {const => "there is a tide in the affairs of men"}}
};

validate_ok {name => "Caesar", constancy => "as the northern star"}, $faithful;
validate_ok {name => "Brutus",
  constancy => "there is a tide in the affairs of men"}, $ambitious;

validate_ok {name => "Cassius",
  constancy => "Cassius from bondage will deliver Cassius"}, $faithful,
  E('/constancy', q{Does not match const: "as the northern star".});

validate_ok(
  {
    name => "Calpurnia",
    constancy =>
      "Do not go forth today. Call it my fear That keeps you in the house"
  },
  $ambitious,
  E(
    '/constancy',
    q{Does not match const: "there is a tide in the affairs of men".}
  )
);

# Now oneOf should work right
# before the fix, this failed with: "All of the oneOf rules match."
# because "likes: chocolate" vs. "peanutbutter" wasn't being considered
my $schema = {
  type       => 'object',
  properties => {
    people => {
      type  => 'array',
      items => {
        oneOf => [
          {'$ref' => '#/definitions/chocolate'},
          {'$ref' => '#/definitions/peanutbutter'}
        ],
      },
    },
  },
  definitions => {
    chocolate => {
      type       => 'object',
      properties => {
        name  => {type  => 'string'},
        age   => {type  => 'number'},
        likes => {const => 'chocolate'}
      },
    },
    peanutbutter => {
      type       => 'object',
      properties => {
        name  => {type  => 'string'},
        age   => {type  => 'number'},
        likes => {const => 'peanutbutter'},
      },
    },
  },
};
validate_ok {
  people => [{name => 'mr. chocolate fan', age => 42, likes => 'peanutbutter'}]
}, $schema;

done_testing;
