use lib '.';
use t::Helper;
use Test::More;
use Mojo::Path;

my $path = Mojo::File->new('/dev/random')
  ->to_rel( Mojo::File->new->path );

my $schema = qq{{
  "type": "object",
  "properties": {
    "age": { "\$ref": "$path#" }
  }
}};

my $parsed = 0;

eval {
  alarm 5;
  my $validator = t::Helper->validator->cache_paths([]);
  validate_ok {}, $schema;
  $parsed = 1;
  alarm 0;
};

like(
  $@,
  qr!Unable to load schema due to potential XXE attack vector: /dev/random!,
 'no DOS due to XXE attack vector'
);

done_testing;
