use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new->schema(
  {properties => {required => {type => "boolean", enum => [Mojo::JSON->true, Mojo::JSON->false]}}});

my @errors = $validator->validate({required => '0'});
is $errors[1]->{message}, 'Expected boolean - got string.', 'string 0 is not detected as boolean';

$validator->coerce(booleans => 1);
for my $value (!!1, !!0) {
  my @errors = $validator->validate({required => $value});
  ok !@errors, "boolean ($value). (@errors)";
}

for my $value (1, "1", "0", "") {
  my @errors = $validator->validate({required => $value});
  ok @errors, "not boolean ($value). @errors";
}

for my $value ("true", "false") {
  my @errors = $validator->validate({required => $value});
  ok !@errors, "boolean ($value). (@errors)";
}

SKIP:{
  skip 'One of Cpanel::JSON::XS or Mojo::JSON::MaybeXS is not installed.'
    unless eval {require Cpanel::JSON::XS && require Mojo::JSON::MaybeXS};
  my $schema = {properties => {disabled => {type => "boolean"}}};
  $validator = JSON::Validator->new->schema($schema);
  $validator->coerce(booleans => 0);
  my $objects = [{disabled => 1}, {disabled => 0}];
  for my $o (@$objects){
    $o->{disabled}
      ? ($o->{disabled} = Mojo::JSON->true)
      : ($o->{disabled} = Mojo::JSON->false);
    @errors = $validator->validate($o);
    ok !@errors, "boolean via Mojo::JSON::MaybeXS ($o->{disabled}). (@errors)";
  }
}


SKIP: {
  skip 'YAML::XS is not installed', 1 unless eval 'require YAML::XS;1';
  $validator->coerce(booleans => 0);    # see that _load_schema_from_text() turns it back on
  my @errors = $validator->validate($validator->_load_schema_from_text("---\nrequired: true\n"));
  ok !@errors, "true in YAML::XS is boolean. (@errors)";
  ok $validator->coerce->{booleans}, 'coerce booleans';
}

done_testing;
