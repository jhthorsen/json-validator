use Mojo::Base -strict;
use Test::More;
use JSON::Validator;
use Mojo::File 'tempdir';

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE};

$ENV{JSON_VALIDATOR_CACHE_PATH} = '/tmp/whatever';
my $jv = JSON::Validator->new;
my @old_files = get_cached_files($jv);

is $jv->cache_paths->[0], '/tmp/whatever', 'back compat env';
shift @{$jv->cache_paths};

my $spec_url = 'https://raw.githubusercontent.com/OAI/OpenAPI-Specification/master/schemas/v2.0/schema.json';
$jv->schema($spec_url);
my @new_files = get_cached_files($jv);
ok @old_files == @new_files, 'remote file not cached in default cache dir';

my $tempdir = tempdir;
$ENV{JSON_VALIDATOR_CACHE_PATH} = join ':', $tempdir->dirname, '/tmp/whatever';
$jv = JSON::Validator->new;
is $jv->cache_paths->[0], $tempdir->dirname, 'env';
$jv->schema($spec_url);
@new_files = get_cached_files($jv);
ok @new_files > @old_files,
  'remote file cached when cache_paths not the default'
  or diag join "\n", @new_files;

done_testing;

sub get_cached_files {
  my ($jv) = @_;
  return sort map { glob "$_/*" } @{$jv->cache_paths};
}
