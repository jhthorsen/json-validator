use Mojo::Base -strict;
use Test::More;
use JSON::Validator;
use Mojo::Util qw( slurp spurt );

my $file      = File::Spec->catfile(File::Basename::dirname(__FILE__), 'spec_split.json');
my $validator = JSON::Validator->new->schema($file);
my @errors    = $validator->validate({firstName => 'yikes!', age => "Women"});

is int(@errors), 2, 'two errors';
is $errors[0]->path,    '/lastName',         'lastName';
is $errors[0]->message, 'Missing property.', 'required';
is_deeply $errors[0]->TO_JSON, {path => '/lastName', message => 'Missing property.'}, 'TO_JSON';
is $errors[1]->path,    '/age',              'age'; # Age should be an integer, so a string should fail

done_testing;
