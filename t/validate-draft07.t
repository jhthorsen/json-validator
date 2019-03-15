use Mojo::Base -strict;
use Mojo::File 'path';
use Mojo::JSON 'decode_json';
use Test::More;
use Test::File::ShareDir -share => { -dist => { 'JSON-Validator' => 'share' } };

use JSON::Validator 'validate_json';

my $draft07
  = path(File::ShareDir::dist_dir('JSON-Validator'),qw(cache 4a31fe43be9e23ca9eb8d9e9faba8892));
plan skip_all => "Cannot open $draft07" unless -r $draft07;

my $schema = decode_json($draft07->slurp);
my @errors = validate_json $schema, $schema;
ok !@errors, "validated draft07" or map { diag $_ } @errors;

done_testing;
