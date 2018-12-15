  use Mojo::Base -strict;
  use Test::More;
  use JSON::Validator;

  my $validator = JSON::Validator->new;
  my @errors    = $validator->schema('data://main/spec.json')
    ->validate({firstName => 'yikes!'});

  is int(@errors), 1, 'one error';
  is $errors[0]->path,    '/lastName',         'lastName';
  is $errors[0]->message, 'Missing property.', 'required';
  is_deeply $errors[0]->TO_JSON,
    {path => '/lastName', message => 'Missing property.'}, 'TO_JSON';

  use Mojo::File 'path';
  push @INC, path(path(__FILE__)->dirname, 'stack')->to_string;
  require Some::Module;

  eval { Some->validate_age1({age => 1}) };
  like $@, qr{age1\.json}, 'could not find age1.json';

  ok !Some->validate_age0({age => 1}), 'validate_age0';
  ok !Some::Module->validate_age0({age => 1}), 'validate_age0';
  ok !Some::Module->validate_age1({age => 1}), 'validate_age1';

  done_testing;

__DATA__
@@ spec.json

{
  "title": "Example Schema",
  "type": "object",
  "required": ["firstName", "lastName"],
  "properties": {
      "firstName": { "type": "string" },
      "lastName": { "type": "string" },
      "age": { "type": "integer", "minimum": 0, "description": "Age in years" }
  }
}

