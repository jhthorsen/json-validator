use Mojo::Base -strict;
use JSON::Validator;
use Test::More;

plan skip_all => 'YAML::XS required'
  unless JSON::Validator::Store->YAML_SUPPORT;

my $jv     = JSON::Validator->new;
my @errors = $jv->schema('data://Some::Module/s_pec-/-ficaTion')
  ->validate({firstName => 'yikes!'});

is int(@errors), 1, 'one error';
is $errors[0]->path,    '/lastName',         'lastName';
is $errors[0]->message, 'Missing property.', 'required';
is_deeply $errors[0]->TO_JSON,
  {path => '/lastName', message => 'Missing property.'}, 'TO_JSON';

done_testing;

package Some::Module;
__DATA__
@@ s_pec-/-ficaTion

---
title: Example Schema
type: object
required:
  - firstName
  - lastName
properties:
  firstName:
    type: string
  lastName:
    type: string
  age:
    type: integer
    minimum: 0
    description: Age in years
