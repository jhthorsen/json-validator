use Mojo::Base -strict;
use Test::More;
use JSON::Validator;
use Mojo::File 'path';

my $file      = path(path(__FILE__)->dirname, 'spec', 'person.json');
my $validator = JSON::Validator->new->schema($file);
my @errors    = $validator->validate({firstName => 'yikes!'});

is int(@errors), 1, 'one error';
is $errors[0]->path,    '/lastName',         'lastName';
is $errors[0]->message, 'Missing property.', 'required';
is_deeply $errors[0]->TO_JSON,
  {path => '/lastName', message => 'Missing property.'}, 'TO_JSON';

my $spec = path($file)->slurp;
$spec =~ s!"#!"person.json#! or die "Invalid spec: $spec";
path("$file.2")->spurt($spec);
ok eval { JSON::Validator->new->schema("$file.2") },
  'test issue #1 where $ref could not point to a file'
  or diag $@;
unlink "$file.2";

# load from cache
is(
  eval { JSON::Validator->new->schema('http://swagger.io/v2/schema.json'); 42 },
  42,
  'loaded from cache'
) or diag $@;

done_testing;
