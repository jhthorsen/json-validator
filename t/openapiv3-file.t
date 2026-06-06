use Mojo::Base -strict;
use JSON::Validator::Schema::OpenAPIv3;
use Mojo::File;
use Mojo::Upload;
use Test::Deep;
use Test::More;

my $cwd    = Mojo::File->new(__FILE__)->dirname;
my $schema = JSON::Validator::Schema::OpenAPIv3->new;
my ($body, $p, @errors);

subtest 'basic' => sub {
  is $schema->specification, 'https://spec.openapis.org/oas/3.0/schema/2021-09-28', 'specification';
  is_deeply $schema->coerce, {booleans => 1, numbers => 1, strings => 1}, 'default coercion';

  $schema = JSON::Validator->new->schema('data://main/spec.yaml')->schema;
  isa_ok $schema, 'JSON::Validator::Schema::OpenAPIv3';

  @errors = @{JSON::Validator->new->schema({openapi => '3.0.0', paths => {}})->schema->errors};
  is "@errors", '/info: Missing property.', 'invalid schema';

  is_deeply(
    $schema->routes->to_array,
    [
      {method => 'post', operation_id => 'submit',  path => '/submit'},
      {method => 'post', operation_id => 'uploadFile',  path => '/upload'},
    ],
    'routes'
  );
};

subtest 'validate_request - file string' => sub {
  my $file = 'file contents\nmore content';

  # Check required works
  $body = {exists => 1,value => {image => $file } };
  @errors = $schema->validate_request([post => '/upload'], {body => \&body});
  is "@errors", "/body/file: Missing property.", 'detects missing file';

  $body = {exists => 1,value => {file => $file } };
  @errors = $schema->validate_request([post => '/upload'], {body => \&body});
  is "@errors", "", 'valid file';
  is_deeply $body, {
    content_type => 'multipart/form-data',
    exists => 1,
    in => 'body',
    name => 'body',
    valid => 1,
    value => {file => $file},
  }, 'valid file';
};

subtest 'validate_request - file placeholder' => sub {
  my $file = Mojo::Upload->new;

  # Check required works
  $body = {exists => 1,value => {image => $file } };
  @errors = $schema->validate_request([post => '/upload'], {body => \&body});
  is "@errors", "/body/file: Missing property.", 'detects missing file';

  $body = {exists => 1,value => {file => $file } };
  @errors = $schema->validate_request([post => '/upload'], {body => \&body});
  is "@errors", "", 'valid file';
  is_deeply $body, {
    content_type => 'multipart/form-data',
    exists => 1,
    in => 'body',
    name => 'body',
    valid => 1,
    value => {file => $file},
  }, 'valid file';
};

subtest 'string in non-file string' => sub {

  $body = {exists => 1,value => {name => 'some string' } };
  @errors = $schema->validate_request([post => '/submit'], {body => \&body});
  is "@errors", "", 'valid file';
  is_deeply $body, {
    content_type => 'multipart/form-data',
    exists => 1,
    value => {name => 'some string'},
    in => 'body',
    name => 'body',
    valid => 1,
  }, 'valid file';
};

subtest 'file placehodler in non-file string' => sub {
  my $file = Mojo::Upload->new;
  $body = {exists => 1,value => {name => $file } };
  @errors = $schema->validate_request([post => '/submit'], {body => \&body});
  is "@errors", "/body/name: Expected string - got file.", 'valid file';
};

done_testing;

sub body {$body}

__DATA__
@@ spec.yaml
openapi: 3.0.0
info:
  title: Test body
  version: 0.8
paths:
  /submit:
    post:
      operationId: submit
      requestBody:
        content:
          multipart/form-data:
            schema:
              type: object
              required:
                - name
              properties:
                name:
                  type: string
  /upload:
    post:
      operationId: uploadFile
      requestBody:
        content:
          multipart/form-data:
            schema:
              type: object
              required:
                - file
              properties:
                file:
                  type: string
                  format: binary
