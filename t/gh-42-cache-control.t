use Mojo::Base -strict;
use Test::More;
use JSON::Validator;
use Mojo::File 'path';
use Mojo::Util;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE};

my $validator = JSON::Validator->new;

my @old_files = _get_cached_file_paths($validator);

# Cache-Control no-store
$validator->schema('https://za.payprop.com/api/docs/api_spec.yaml');
isa_ok($validator->schema, 'Mojo::JSON::Pointer');

my @new_files = _get_cached_file_paths($validator);
ok(@old_files == @new_files, 'no-store was not cached');

my $spec_max_age = 'https://raw.githubusercontent.com/APIs-guru/openapi-directory/master/APIs/instagram.com/1.0.0/swagger.yaml';
$validator->schema($spec_max_age);
isa_ok($validator->schema, 'Mojo::JSON::Pointer');

@new_files = _get_cached_file_paths($validator);
ok(@old_files == @new_files - 2, 'max-age was cached');

# forecfully "expire" the cache"
my ($expire_file) = grep { /\.expires/ } @new_files;
my $time = path($expire_file)->slurp;
ok($time, ' ... with an expiry time');

Mojo::Util::spurt(time - 10,$expire_file);

$validator->schema($spec_max_age);
isa_ok($validator->schema, 'Mojo::JSON::Pointer');

@new_files = _get_cached_file_paths($validator);
ok(@old_files == @new_files - 2, 'max-age was cached');

# forecfully "expire" the cache"
($expire_file) = grep { /\.expires/ } @new_files;
ok($time > time, 'cache was updated');

# cleanup
for my $new_file (@new_files) {
  next if grep { $new_file eq $_ } @old_files;
  unlink($new_file) || warn "Couldn't unlink $new_file: $!";
}

done_testing;

sub _get_cached_file_paths {
  my ($validator) = @_;
  my @files;
  for (@{$validator->cache_paths}) {
    push(@files,glob( "$_/*"));
  }
  return @files;
}
