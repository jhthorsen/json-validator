use Mojo::Base -strict;
use Test::More;
use Swagger2::SchemaValidator;
use utf8;

my $validator = Swagger2::SchemaValidator->new;
my $schema = {type => 'object',
  properties => {nick => {type => 'string', minLength => 3, maxLength => 10, pattern => qr{^\w+$}}}};

my @errors = $validator->validate({nick => 'batman'}, $schema);
is "@errors", "", "batman";

@errors = $validator->validate({nick => 1000}, $schema);
is "@errors", "/nick: Expected string - got number.", "integer";

@errors = $validator->validate({nick => '1000'}, $schema);
is "@errors", "", "number as string";

@errors = $validator->validate({nick => 'aa'}, $schema);
is "@errors", "/nick: String is too short: 2/3.", "too short";

@errors = $validator->validate({nick => 'a' x 11}, $schema);
is "@errors", "/nick: String is too long: 11/10.", "too long";

@errors = $validator->validate({nick => '[nick]'}, $schema);
like "@errors", qr{/nick: String does not match}, "pattern";

delete $schema->{properties}{nick}{pattern};
@errors = $validator->validate({nick => 'Déjà vu'}, $schema);
is "@errors", "", "unicode";

done_testing;
