use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $strict_validator = JSON::Validator->new;
my $coerce_validator = JSON::Validator->new->coerce({numbers => 1});

my $schema
  = {type => 'object', properties => {mynumber => {type => 'number'}}};

my @errors = $strict_validator->validate({mynumber => -1}, $schema);
is "@errors", "", "strict -1";

@errors = $strict_validator->validate({mynumber => '-1'}, $schema);
is "@errors", '/mynumber: Expected number - got string.', "strict '-1'";

@errors = $coerce_validator->validate({mynumber => -1}, $schema);
is "@errors", "", "coerce -1";

@errors = $coerce_validator->validate({mynumber => '-1'}, $schema);
is "@errors", "", "coerce '-1'";

@errors = $coerce_validator->validate({mynumber => '-1.41'}, $schema);
is "@errors", "", "coerce '-1.41'";

@errors = $coerce_validator->validate({mynumber => '-1.41e-29'}, $schema);
is "@errors", "", "coerce '-1.41e-29'";

@errors = $coerce_validator->validate({mynumber => '-1.41pi-29'}, $schema);
is "@errors", '/mynumber: Expected number - got string.', "coerce '-1.41pi-29'";

done_testing;
__END__
