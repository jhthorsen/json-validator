use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

plan skip_all => $@ unless eval 'require YAML::Syck;1';

use JSON::Validator;
Mojo::Util::monkey_patch('JSON::Validator' => _yaml_module => sub {'YAML::Syck'});

my $validator = JSON::Validator->new->schema('data://main/yaml-syck.yml');
my @errors = $validator->validate({firstName => 'Jan Henning', lastName => 'Thorsen', age => 42});

ok $INC{'YAML/Syck.pm'}, 'YAML::Syck is loaded';
ok !$INC{'YAML/XS.pm'}, 'YAML::XS is not loaded';
is "@errors", "/: Properties not allowed: age.", "additionalProperties: false";

done_testing;

__DATA__
@@ yaml-syck.yml
---
type: object
required: [firstName, lastName]
additionalProperties: false
properties:
  firstName: { type: string }
  lastName: { type: string }
