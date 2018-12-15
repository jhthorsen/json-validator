use lib '.';
use t::Helper;
use Mojo::File 'path';

my $file = path(path(__FILE__)->dirname, 'spec', 'with-relative-ref.json');
my $validator = t::Helper->validator->cache_paths([]);
validate_ok {age => -1}, $file, E('/age', '-1 < minimum(0)');

use Mojolicious::Lite;
push @{app->static->paths}, path(__FILE__)->dirname;
$validator->ua(app->ua);
validate_ok {age => -2},
  app->ua->server->url->clone->path('/spec/with-relative-ref.json'),
  E('/age', '-2 < minimum(0)');

done_testing;
