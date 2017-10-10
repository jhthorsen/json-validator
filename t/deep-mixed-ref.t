use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $file
  = File::Spec->catfile(File::Basename::dirname(__FILE__), 'spec', 'with-deep-mixed-ref.json');
my $validator = JSON::Validator->new(cache_paths => [])->schema($file);
my @errors = $validator->validate({age => 1, weight => {mass => 72, unit => 'kg'}, height => 100});
is int(@errors), 0, 'valid input';

use Mojolicious::Lite;
push @{app->static->paths}, File::Basename::dirname(__FILE__);
$validator->ua(app->ua);
$validator->schema(app->ua->server->url->clone->path('/spec/with-relative-ref.json'));
@errors = $validator->validate({age => 'not a number'});
is int(@errors), 1, 'invalid age';

done_testing;
