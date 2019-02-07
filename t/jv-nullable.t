use lib '.';
use t::Helper;

sub j { Mojo::JSON::decode_json(Mojo::JSON::encode_json($_[0])); }

my $schema = {
  type => 'object',
  properties => {
    nick => {type => 'string'}
  }
};

validate_ok {nick => 'batman'}, $schema;
validate_ok {nick => undef}, $schema,
  E('/nick', 'Expected string - got null.');

$schema->{properties}{nick}{nullable} = true;

validate_ok {nick => 'batman'}, $schema;
validate_ok {nick => undef}, $schema;

delete $schema->{properties}{nick}{nullable};

validate_ok {nick => 'batman'}, $schema;
validate_ok {nick => undef}, $schema,
  E('/nick', 'Expected string - got null.');

done_testing;
