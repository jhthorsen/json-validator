use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec;
use Mojolicious::Command::swagger2;

plan skip_all => $^O if $^O eq 'MSWin32';

my $cmd = Mojolicious::Command::swagger2->new;
close $Mojolicious::Command::swagger2::OUT;
open $Mojolicious::Command::swagger2::OUT, '>', \my $stdout;

$stdout = '';
$cmd->run('client');
like $stdout, qr{\# Get documentation for a method.*swagger2 client}s, 'client usage';

$stdout = '';
$cmd->run('client', File::Spec->catfile(qw(t blog api.json)));
like $stdout, qr{removePost\s+showPost\s+storePost\s+updatePost}s, 'list methods';

$ENV{SWAGGER_API_FILE} = File::Spec->catfile(qw(t blog api.json));
$stdout = '';
$cmd->run(qw(client removePost help));
like $stdout, qr,DELETE http://localhost/api/posts/\{id\},, 'method help';

done_testing;
