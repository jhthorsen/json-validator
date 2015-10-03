use strict;
use Test::More;
use File::Spec;
use Mojo::JSON 'decode_json';
use Mojo::Loader 'data_section';
use Mojo::Util 'md5_sum';

plan skip_all => 'Author test' unless -d './.git';

my @url = qw(
  http://git.io/vcKD4
  https://raw.githubusercontent.com/jhthorsen/swagger2/master/lib/Swagger2/error.json
);

my $error_json = data_section qw( main error.json );
ok decode_json($error_json), 'error_json';

{
  my $file = File::Spec->catfile(qw( lib Swagger2 error.json ));
  open my $FH, '>', $file or die "Write $file: $!";
  print $FH $error_json;
}

for my $url (@url) {
  my $file = File::Spec->catfile(qw( lib Swagger2 public cache ), md5_sum $url);
  open my $FH, '>', $file or die "Write $file: $!";
  print $FH $error_json;
}

done_testing;

__DATA__
@@ error.json
{
  "type" : "object",
  "required": [ "errors" ],
  "properties": {
    "errors": {
      "type": "array",
      "items": {
        "type" : "object",
        "required": [ "message", "path" ],
        "properties": {
          "message": { "type": "string" },
          "path": { "type": "string" }
        }
      }
    }
  }
}
