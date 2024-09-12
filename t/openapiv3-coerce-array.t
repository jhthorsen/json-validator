use Mojo::Base -strict;
use JSON::Validator;
use Test::More;

my $schema = JSON::Validator->new->schema('data://main/openapi.yaml')->schema;
my ($body, $query, @errors);

subtest 'number to array' => sub {
  $body   = {exists => 1, value => {id => 42}};
  @errors = $schema->validate_request([post => '/test'], {body => \&body});
  is "@errors", "", "valid";
};

subtest 'string to array' => sub {
  $body   = {exists => 1, value => {id => '42'}};
  @errors = $schema->validate_request([post => '/test'], {body => \&body});
  is "@errors", "", "valid";
};

subtest 'already an array' => sub {
  $body   = {exists => 1, value => {id => [42, '43']}};
  @errors = $schema->validate_request([post => '/test'], {body => \&body});
  is "@errors", "", "valid";
};

subtest 'parameter array schema is $ref' => sub {
  $query  = {exists => 1, value => [42, 43]};
  @errors = $schema->validate_request([get => '/test'], {query => \&query});
  is "@errors", "", "valid";
};

done_testing;

sub body  {$body}
sub query {$query}

__DATA__
@@ openapi.yaml
---
openapi: 3.0.0
info:
  title: Upload test
  version: 1.0.0
servers:
- url: http://example.com/api
paths:
  /test:
    post:
      operationId: testPost
      requestBody:
        required: true
        content:
          application/x-www-form-urlencoded:
            schema:
              properties:
                id:
                  type: array
                  items:
                    type: integer
      responses:
        200:
          description: OK
    get:
      parameters:
        - name: id
          in: query
          required: true
          schema:
            $ref: '#/components/schemas/IntArray'
      responses:
        200:
          description: OK
components:
  schemas:
    IntArray:
      type: array
      items:
        type: integer
