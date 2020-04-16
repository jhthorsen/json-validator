use Mojo::Base -strict;
use JSON::Validator;
use Mojo::File 'path';
use Test::More;

my $workdir = path(__FILE__)->dirname;
my $file    = path($workdir, 'spec', 'with-deep-mixed-ref.json');
my $jv      = JSON::Validator->new(cache_paths => [])->schema($file);
my @errors  = $jv->validate(
  {age => 1, weight => {mass => 72, unit => 'kg'}, height => 100});
is int(@errors), 0, 'valid input';

use Mojolicious::Lite;
push @{app->static->paths}, $workdir;
$jv->store->ua(app->ua);
$jv->schema(app->ua->server->url->clone->path('/spec/with-relative-ref.json'));
@errors = $jv->validate({age => 'not a number'});
is int(@errors), 1, 'invalid age';

done_testing;
