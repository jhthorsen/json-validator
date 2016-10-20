use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new->schema({properties => {required => {type => 'boolean'}}});

my @errors = $validator->validate({required => '0'});
is $errors[0]->{message}, 'Expected boolean - got string.', 'string 0 is not detected as boolean';

$validator->coerce(booleans => 1);
for my $value (!!1, !!0) {
  my @errors = $validator->validate({required => $value});
  ok !@errors, "boolean ($value). (@errors)";
}

for my $value (1, '1', '0', '') {
  my @errors = $validator->validate({required => $value});
  ok @errors, "not boolean ($value). @errors";
}

for my $value ('true', 'false') {
  my @errors = $validator->validate({required => $value});
  ok !@errors, "boolean ($value). (@errors)";
}

SKIP: {
  skip 'YAML::XS is not installed', 1 unless eval 'require YAML::XS;1';
  $validator->coerce(booleans => 0);    # see that _load_schema_from_text() turns it back on
  my @errors = $validator->validate($validator->_load_schema_from_text("---\nrequired: true\n"));
  ok !@errors, "true in YAML::XS is boolean. (@errors)";
  ok $validator->coerce->{booleans}, 'coerce booleans';
}

SKIP: {
  skip 'boolean not installed', 1 unless eval 'require boolean;1';
  my @errors = $validator->validate({type => 'boolean'},
    {type => 'object', properties => {type => {type => 'string'}}});
  is "@errors", "", "avoid Can't use string (\"boolean\") as a SCALAR";
}

done_testing;
