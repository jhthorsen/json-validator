use Mojo::Base -strict;
use Test::More;
use Scalar::Util qw( refaddr );
use JSON::Validator;


my $original_validate;

BEGIN {
  $original_validate = \&JSON::Validator::_validate;
}

my %refCounts;

{
  no warnings 'redefine';

  sub JSON::Validator::_validate {
    my ($self, $data, $path, $schema) = @_;
    $refCounts{refaddr($data)}++ if ref $data;
    goto &$original_validate;
  }
}


my $schema = <<'EOS';
{
  "type": "array",
  "items": {
    "type": "object",
    "properties": {
      "level1": {
        "type": "object",
        "properties": {
          "level2": {
            "type": "object",
            "properties": {
              "level3": {
                "type": "string"
              }
            }
          }
        }
      }
    }
  }
}
EOS

my $object = {level1 => {level2 => {level3 => 'Test',},},};

my $data = [$object, $object, $object,];


subtest 'active' => sub {
  my $validator = JSON::Validator->new();
  $validator->recursive_data_protection(1);

  $validator->schema($schema);

  %refCounts = ();
  my @errors = $validator->validate($data);

  is($refCounts{refaddr($object->{level1}->{level2})}, 1,
    "With recursive_data_protection active we should only see the second level once"
  );
};


subtest 'inactive' => sub {
  my $validator = JSON::Validator->new();
  $validator->recursive_data_protection(0);

  $validator->schema($schema);

  %refCounts = ();
  my @errors = $validator->validate($data);

  is($refCounts{refaddr($object->{level1}->{level2})}, 3,
    "With recursive_data_protection deactivated we should see the second level three times"
  );
};


done_testing;
