use Mojo::Base -strict;
use JSON::Validator;
use Test::More;

my $schema = JSON::Validator->new->schema('data://main/spec.yaml')->schema;
my ($body, @errors);

sub body {$body}

subtest '*/* w/ required body' => sub {
  subtest 'content-type is missing' => sub {
    $body = {exists => 0};
    @errors = $schema->validate_request([post => '/pets_any'], {body => \&body});
    is "@errors", "/body: Missing property.", 'invalid request body';

    $body = {exists => 1, value => {name => 'kitty'}};
    @errors = $schema->validate_request([post => '/pets_any'], {body => \&body});
    is "@errors", "", 'valid request body';

    $body = {exists => 1, value => {age => 42}};
    @errors = $schema->validate_request([post => '/pets_any'], {body => \&body});
    is "@errors", "/body/name: Missing property.", 'invalid request body';
  };

  subtest 'content-type is empty string' => sub {
    $body = {exists => 0, content_type => ''};
    @errors = $schema->validate_request([post => '/pets_any'], {body => \&body});
    is "@errors", "/body: Missing property.", 'invalid request body';

    $body = {exists => 1, value => {name => 'kitty'}, content_type => ''};
    @errors = $schema->validate_request([post => '/pets_any'], {body => \&body});
    is "@errors", "", 'valid request body';

    $body = {exists => 1, value => {age => 42}, content_type => ''};
    @errors = $schema->validate_request([post => '/pets_any'], {body => \&body});
    is "@errors", "/body/name: Missing property.", 'invalid request body';
  };

  subtest 'content-type is application/json' => sub {
    $body = {exists => 0};
    @errors = $schema->validate_request([post => '/pets_any'], {body => \&body});
    is "@errors", "/body: Missing property.", 'invalid request body';

    $body = {exists => 1, value => {name => 'kitty'}, content_type => 'application/json'};
    @errors = $schema->validate_request([post => '/pets_any'], {body => \&body});
    is "@errors", "", 'valid request body';

    $body = {exists => 1, value => {age => 42}, content_type => 'application/json'};
    @errors = $schema->validate_request([post => '/pets_any'], {body => \&body});
    is "@errors", "/body/name: Missing property.", 'invalid request body';
  };

  subtest 'content-type is application/json; charset=utf-8' => sub {
    $body = {exists => 0};
    @errors = $schema->validate_request([post => '/pets_any'], {body => \&body});
    is "@errors", "/body: Missing property.", 'invalid request body';

    $body = {exists => 1, value => {name => 'kitty'}, content_type => 'application/json; charset=utf-8'};
    @errors = $schema->validate_request([post => '/pets_any'], {body => \&body});
    is "@errors", "", 'valid request body';

    $body = {exists => 1, value => {age => 42}, content_type => 'application/json; charset=utf-8'};
    @errors = $schema->validate_request([post => '/pets_any'], {body => \&body});
    is "@errors", "/body/name: Missing property.", 'invalid request body';
  };
};

subtest 'application/json w/ body' => sub {
  subtest 'content-type is missing' => sub {
    $body = {exists => 0};
    @errors = $schema->validate_request([post => '/pets_json'], {body => \&body});
    is "@errors", "/body: Missing property.", 'invalid request body';

    $body = {exists => 1, value => {name => 'kitty'}};
    @errors = $schema->validate_request([post => '/pets_json'], {body => \&body});
    is "@errors", "", 'valid request body';

    $body = {exists => 1, value => {age => 42}};
    @errors = $schema->validate_request([post => '/pets_any'], {body => \&body});
    is "@errors", "/body/name: Missing property.", 'invalid request body';
  };

  subtest 'content-type is empty string' => sub {
    $body = {exists => 0, content_type => ''};
    @errors = $schema->validate_request([post => '/pets_json'], {body => \&body});
    is "@errors", "/body: Missing property.", 'invalid request body';

    $body = {exists => 1, value => {name => 'kitty'}, content_type => ''};
    @errors = $schema->validate_request([post => '/pets_json'], {body => \&body});
    is "@errors", "", 'valid request body';

    $body = {exists => 1, value => {age => 42}, content_type => ''};
    @errors = $schema->validate_request([post => '/pets_any'], {body => \&body});
    is "@errors", "/body/name: Missing property.", 'invalid request body';
  };

  subtest 'content-type is application/json' => sub {
    $body = {exists => 0};
    @errors = $schema->validate_request([post => '/pets_json'], {body => \&body});
    is "@errors", "/body: Missing property.", 'invalid request body';

    $body = {exists => 1, value => {name => 'kitty'}, content_type => 'application/json'};
    @errors = $schema->validate_request([post => '/pets_json'], {body => \&body});
    is "@errors", "", 'valid request body';

    $body = {exists => 1, value => {age => 42}, content_type => 'application/json'};
    @errors = $schema->validate_request([post => '/pets_json'], {body => \&body});
    is "@errors", "/body/name: Missing property.", 'invalid request body';
  };

  subtest 'content-type is application/json; charset=utf-8' => sub {
    $body = {exists => 1, value => {name => 'kitty'}, content_type => 'application/json; charset=utf-8'};
    @errors = $schema->validate_request([post => '/pets_json'], {body => \&body});
    is "@errors", "", 'valid request body';

    $body = {exists => 1, value => {age => 42}, content_type => 'application/json; charset=utf-8'};
    @errors = $schema->validate_request([post => '/pets_json'], {body => \&body});
    is "@errors", "/body/name: Missing property.", 'invalid request body';
  };

  subtest 'content-type is application/xml' => sub {
    $body = {exists => 0, content_type => 'application/xml'};
    @errors = $schema->validate_request([post => '/pets_json'], {body => \&body});
    is "@errors", "/body: Expected application/json - got application/xml.", 'invalid request body';

    $body = {exists => 1, value => {name => 'kitty'}, content_type => 'application/xml'};
    @errors = $schema->validate_request([post => '/pets_json'], {body => \&body});
    is "@errors", "/body: Expected application/json - got application/xml.", 'invalid request body';

    $body = {exists => 1, value => {age => 42}, content_type => 'application/xml'};
    @errors = $schema->validate_request([post => '/pets_json'], {body => \&body});
    is "@errors", "/body: Expected application/json - got application/xml.", 'invalid request body';
  };
};

subtest 'w/o body' => sub {
  $body = {exists => 0};
  @errors = $schema->validate_request([post => '/pets/publish'], {body => \&body});
  is "@errors", "", 'valid request body';

  $body = {exists => 0, content_type => ''};
  @errors = $schema->validate_request([post => '/pets/publish'], {body => \&body});
  is "@errors", "", 'valid request body';

  $body = {exists => 0, content_type => 'application/xml'};
  @errors = $schema->validate_request([post => '/pets/publish'], {body => \&body});
  is "@errors", "", 'valid request body';

  $body = {exists => 0, content_type => 'application/json; charset=utf-8'};
  @errors = $schema->validate_request([post => '/pets/publish'], {body => \&body});
  is "@errors", "", 'valid request body';
};

done_testing;

__DATA__
@@ spec.yaml
openapi: 3.0.0
info:
  title: Style And Explode
  version: ""
paths:
  /pets_any:
    post:
      requestBody:
        required: true
        content:
          "*/*":
            schema:
              type: object
              required:
                - name
              properties:
                name:
                  type: string
      responses:
        "200":
          description: success
          schema:
            type: object
  /pets_json:
    post:
      requestBody:
        required: true
        content:
          "application/json":
            schema:
              type: object
              required:
                - name
              properties:
                name:
                  type: string
      responses:
        "200":
          description: success
          schema:
            type: object
  /pets/publish:
    post:
      description: example of endpoint with no request body
      responses:
        "200":
          description: success
          schema:
            type: object
