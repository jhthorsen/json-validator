use lib '.';
use utf8;
use t::Helper;

my $schema = {type => 'object',
  properties => {nick => {type => 'string', minLength => 3, maxLength => 10, pattern => qr{^\w+$}}}};

validate_ok {nick => 'batman'}, $schema;
validate_ok {nick => 1000},     $schema, E('/nick', 'Expected string - got number.');
validate_ok {nick => '1000'},   $schema;
validate_ok {nick => 'aa'},     $schema, E('/nick', 'String is too short: 2/3.');
validate_ok {nick => 'a' x 11}, $schema, E('/nick', 'String is too long: 11/10.');
like +join('', jv->validate({nick => '[nick]'})), qr{/nick: String does not match}, 'String does not match';

delete $schema->{properties}{nick}{pattern};
validate_ok {nick => 'Déjà vu'}, $schema;

jv->coerce('str');
validate_ok {nick => 1000}, $schema;

# https://github.com/mojolicious/json-validator/issues/134
validate_ok(
  {credit_card_number => '5252525252525252'},
  {
    type       => "object",
    required   => ["credit_card_number"],
    properties => {credit_card_number => {type => "string", minLength => 15, maxLength => 16}}
  }
);

my $string_constant = {type => 'string', const => 'foo'};
validate_ok 'foo', $string_constant;
validate_ok 'bar', $string_constant, E('/', q{Does not match const: "foo".});

my $empty_string_constant = {type => 'string', const => ''};
validate_ok '', $empty_string_constant;
validate_ok 'bar', $empty_string_constant, E('/', q{Does not match const: "".});

done_testing;
