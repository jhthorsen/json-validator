use Mojo::Base -strict;
use Mojo::Loader;
use Swagger2;
use Test::More;

plan skip_all => 'YAML::XS is requried' unless eval 'use YAML::XS;1';

my $file = "data://main/api.yaml";
my $yaml = Mojo::Loader::data_section('main', 'api.yaml');
my @errors;

@errors = Swagger2->new($file)->validate;
is_deeply \@errors, [], 'new validate';

@errors = Swagger2->new($file)->expand->validate;
is_deeply \@errors, [], 'new expand validate';

@errors = Swagger2->new->load($file)->validate;
is_deeply \@errors, [], 'new load validate';

@errors = Swagger2->new->load($file)->expand->validate;
is_deeply \@errors, [], 'new load expand validate';

@errors = Swagger2->new->parse($yaml)->validate;
is_deeply \@errors, [], 'new parse validate';

@errors = Swagger2->new->parse($yaml)->expand->validate;
is_deeply \@errors, [], 'new parse expand validate';

done_testing;

__DATA__
@@ api.yaml
---
swagger: "2.0"
info:
  title: Example API
  version: "1.0"
basePath: /api
paths:
  /welcome:
    get:
      parameters:
      - name: param
        in: query
        required: true
        type: string
      responses:
        200:
          description: success
