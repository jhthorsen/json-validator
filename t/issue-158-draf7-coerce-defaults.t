use lib '.';
use t::Helper;

my $validator = JSON::Validator->new(coerce => 'defaults');

eval {
  $validator->load_and_validate_schema(
    {'$schema' => 'http://json-schema.org/draft-07/schema#'},
    {schema    => 'http://json-schema.org/draft-07/schema#'},
  );
};

ok !$@, "load_and_validate_schema draft-07 \$@=$@";

done_testing;
