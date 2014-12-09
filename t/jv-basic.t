use Mojo::Base -strict;
use Test::More;
use Swagger2::SchemaValidator;
use Mojo::JSON;

my $validator = Swagger2::SchemaValidator->new;
my @errors;

for (undef, [], {}, 123, "foo") {
  my $type = $_;
  @errors = $validator->validate(j($_), {type => 'any'});
  $type //= 'null';
  is "@errors", "", "any $type";
}

@errors = $validator->validate(j(undef), {type => 'null'});
is "@errors", "", "null";
@errors = $validator->validate(j(1), {type => 'null'});
is "@errors", "/: Not null.", "not null";

@errors = $validator->validate(j(Mojo::JSON->false), {type => 'boolean'});
is "@errors", "", "boolean false";
@errors = $validator->validate(j(Mojo::JSON->true), {type => 'boolean'});
is "@errors", "", "boolean true";
@errors = $validator->validate(j("foo"), {type => 'boolean'});
is "@errors", "/: Expected boolean - got string.", "not boolean";

done_testing;

sub j {
  Mojo::JSON::decode_json(Mojo::JSON::encode_json($_[0]));
}
