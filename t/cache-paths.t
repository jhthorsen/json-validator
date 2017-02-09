use Mojo::Base -strict;
use JSON::Validator;
use Mojo::File 'path';
use Test::More;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE};

my $validator = JSON::Validator->new;
my $url       = 'https://za.payprop.com/api/docs/api_spec.yaml';

$validator->schema($url);
ok + (!-e path($validator->cache_paths->[0], Mojo::Util::md5_sum($url))), 'not cached';

done_testing;
