use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $validator = JSON::Validator->new->schema({properties => {foo => {type => "boolean"}}});

for my $value (!!1, !!0) {
  my @errors = $validator->validate({foo => $value});
  ok !@errors, "boolean value: $value";
}

for my $value (1, "1", "0", "") {
  my @errors = $validator->validate({foo => $value});
  ok @errors, "not boolean value: $value";
}

done_testing;
