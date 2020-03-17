use Mojo::Base -strict;
use JSON::Validator;
use Test::More;

my $jv = JSON::Validator->new;
my @errors
  = $jv->schema('data://main/spec.json')->validate({firstName => 'yikes!'});

is $jv->{schemas}{'data://main/spec.json'}{title}, 'Example Schema',
  'registered this schema for reuse';

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

eval { Mojolicious::Plugin::TestX->validate('data:///spec.json', {}) };
ok !$@, 'found spec.json in main' or diag $@;

@errors = $jv->schema('data://main/spec.json')->validate({});
like "@errors", qr{firstName.*lastName}, 'required is sorted';

package Mojolicious::Plugin::TestX;
sub validate { $jv->schema($_[1])->validate($_[2]) }

package main;
done_testing;

__DATA__
@@ spec.json

{
  "title": "Example Schema",
  "type": "object",
  "required": ["lastName", "firstName"],
  "properties": {
      "firstName": { "type": "string" },
      "lastName": { "type": "string" },
      "age": { "type": "integer", "minimum": 0, "description": "トシ" }
  }
}

