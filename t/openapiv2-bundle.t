use Mojo::Base -strict;
use JSON::Validator::Schema::OpenAPIv2;
use JSON::Validator::Util qw(str2data);
use Mojo::Loader qw(data_section);
use Test::Deep;
use Test::More;

my $cwd    = Mojo::File->new(__FILE__)->dirname;
my $schema = JSON::Validator::Schema::OpenAPIv2->new($cwd->child(qw(spec v2-bundle.yaml)));
is_deeply $schema->errors, [], 'schema errors' or diag explain $schema->errors;

my $bundle = $schema->bundle;
is_deeply $bundle->errors, [], 'bundle errors' or diag explain $bundle->errors;

my $from_data = JSON::Validator::Schema::OpenAPIv2->new($bundle->data);
is_deeply $from_data->errors, [], 'from_data errors' or diag explain $from_data->errors;

is_deeply $from_data->data, str2data(data_section(qw(main exp.yaml))), 'from_data schema'
  or diag explain $from_data->data;

done_testing;

__DATA__
@@ exp.yaml
---
swagger: "2.0"
info:
  title: Bundled
  version: "1.0"
basePath: /api
paths:
  /user:
    get:
      parameters:
        - $ref: "#/parameters/paths_yaml-parameters_id"
      responses:
        200:
          description: A user
          schema:
            $ref: "#/x-def/User"

x-def:
  User:
    properties:
      name:
        type: string

parameters:
  paths_yaml-parameters_id:
    in: path
    name: id
    required: true
    type: string
