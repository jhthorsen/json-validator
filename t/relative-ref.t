use lib '.';
use t::Helper;

my $file = File::Spec->catfile(File::Basename::dirname(__FILE__), 'spec', 'with-relative-ref.json');
my $validator = t::Helper->validator->cache_paths([]);
validate_ok {age => -1}, $file, E('/age', '-1 < minimum(0)');

use Mojolicious::Lite;
push @{app->static->paths}, File::Basename::dirname(__FILE__);
$validator->ua(app->ua);
validate_ok {age => -2}, app->ua->server->url->clone->path('/spec/with-relative-ref.json'),
  E('/age', '-2 < minimum(0)');

done_testing;
