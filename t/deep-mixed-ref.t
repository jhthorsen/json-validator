use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $file
  = File::Spec->catfile(File::Basename::dirname(__FILE__), 'spec', 'with-deep-mixed-ref.json');
my $validator = JSON::Validator->new(cache_paths => [])->schema($file);
is $validator->schema->get('/properties/age/type'),       'integer', 'loaded age.json from disk';
is $validator->schema->get('/properties/height/minimum'), '5',       'loaded height from file';
is $validator->schema->get('/properties/weight/properties/unit/type'), 'string',
  'loaded weight-unit type from file';

use Mojolicious::Lite;
push @{app->static->paths}, File::Basename::dirname(__FILE__);
$validator->ua(app->ua);
$validator->schema(app->ua->server->url->clone->path('/spec/with-relative-ref.json'));
is $validator->schema->get('/properties/age/type'), 'integer', 'loaded age.json from http';

my @errors = $validator->validate({age => 'not a number'});
is int(@errors), 1, 'invalid age';

done_testing;
