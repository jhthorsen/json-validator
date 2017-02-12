use Mojo::Base -strict;
use Test::More;
use JSON::Validator;
use File::Temp;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE};

my $validator = JSON::Validator->new;
my @old_files = get_cached_files($validator);

$validator->schema('https://za.payprop.com/api/docs/api_spec.yaml');
my @new_files = get_cached_files($validator);
ok @old_files == @new_files, 'remote file not cached in default cache dir';

my $tmp_dir = File::Temp->newdir;
$validator = JSON::Validator->new(cache_paths => [$tmp_dir->dirname, @{$validator->cache_paths}]);
$validator->schema('https://za.payprop.com/api/docs/api_spec.yaml');
@new_files = get_cached_files($validator);
ok @new_files > @old_files, 'remote file cached when cache_paths not the default'
  or diag join "\n", @new_files;

done_testing;

sub get_cached_files {
  my ($validator) = @_;
  return sort map { glob "$_/*" } @{$validator->cache_paths};
}
