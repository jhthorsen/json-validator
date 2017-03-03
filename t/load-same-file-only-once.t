use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $file = File::Spec->catfile(File::Basename::dirname(__FILE__),
  'spec', 'ref-same-file-at-many-levels.json');
my $validator = JSON::Validator->new(cache_paths => [])->schema($file);
is $validator->schema->get('/properties/age_one/type'), 'integer',
  'loaded age.json from disk to age_one';
is $validator->schema->get('/properties/age_two/type'), 'integer',
  'loaded age.json from disk to age_two';
is keys %{$validator->{cached}}, 2,
  'Loaded the same file only once even if calling in two different ways';

done_testing;
