use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new->schema(
  {properties => {required => {type => "boolean", enum => [Mojo::JSON->true, Mojo::JSON->false]}}});

for my $value (!!1, !!0) {
  my @errors = $validator->validate({required => $value});
  ok !@errors, "boolean ($value). (@errors)";
}

for my $value (1, "1", "0", "") {
  my @errors = $validator->validate({required => $value});
  ok @errors, "not boolean ($value). @errors";
}

if (eval 'require YAML::XS;1') {
  my @errors = $validator->validate(YAML::XS::Load("---\nrequired: true\n"));
  ok !@errors, "true in YAML::XS is boolean. (@errors)";
}
else {
  diag "YAML::XS is not installed";
}

done_testing;
