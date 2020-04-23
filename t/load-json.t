use Mojo::Base -strict;
use JSON::Validator;
use Mojo::File 'path';
use Test::More;

my $file   = path(path(__FILE__)->dirname, 'spec', 'person.json');
my $jv     = JSON::Validator->new->schema($file);
my @errors = $jv->validate({firstName => 'yikes!'});

is $jv->{schemas}{Mojo::File::path(qw(t spec person.json))->to_abs}{title},
  'Example Schema', 'registered this schema for reuse';

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

# we must load from cache, or we will die
is(
  eval {
    $jv
      = JSON::Validator->new(ua => undef)
      ->schema('http://swagger.io/v2/schema.json');
    42;
  },
  42,
  'loaded from cache'
) or diag $@;

is $jv->{schemas}{'http://swagger.io/v2/schema.json'}{title},
  'A JSON Schema for Swagger 2.0 API.',
  'registered this referenced schema for reuse';

is $jv->{schemas}{'http://json-schema.org/draft-04/schema'}{description},
  'Core schema meta-schema', 'registered this referenced schema for reuse';

done_testing;
