use Mojo::Base -strict;
use Test::More;
use JSON::Validator;
use File::Temp;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE};

my $validator = JSON::Validator->new;

my @old_files = _get_cached_file_paths($validator);

$validator->schema('https://za.payprop.com/api/docs/api_spec.yaml');
isa_ok($validator->schema, 'Mojo::JSON::Pointer');

my @new_files = _get_cached_file_paths($validator);
ok(@old_files == @new_files, 'remote file not cached in default cache dir');

my $tmp_dir = File::Temp->newdir;
$validator = JSON::Validator->new(cache_paths => [@{$validator->cache_paths}, $tmp_dir->dirname]);

$validator->schema('https://za.payprop.com/api/docs/api_spec.yaml');
isa_ok($validator->schema, 'Mojo::JSON::Pointer');

@new_files = _get_cached_file_paths($validator);
ok(@new_files > @old_files, 'remote file cached when cache_paths not the default');

done_testing;

sub _get_cached_file_paths {
  my ($validator) = @_;
  my @files;
  for (@{$validator->cache_paths}) {
    push(@files, glob("$_/*"));
  }
  return @files;
}
