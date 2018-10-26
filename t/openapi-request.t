use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Mojo::JSON qw(false true);
use Mojolicious::Controller;
use JSON::Validator::OpenAPI::Mojolicious;

my $t = Test::Mojo->new;
my ($c, $req, $tx);

my $openapi = JSON::Validator::OpenAPI::Mojolicious->new;
my $input   = {};

# formData
make_request(
  qq(multipart/form-data; boundary=---------------------------9051914041544843365972754266),
  qq(-----------------------------9051914041544843365972754266\x0d\x0a),
  qq(Content-Disposition: form-data; name="age"\x0d\x0a\x0d\x0a),
  qq(42\x0d\x0a),
  qq(-----------------------------9051914041544843365972754266\x0d\x0a),
  qq(Content-Disposition: form-data; name="too_cool"\x0d\x0a\x0d\x0a),
  qq(false\x0d\x0a),
  qq(-----------------------------9051914041544843365972754266\x0d\x0a),
  qq(Content-Disposition: form-data; name="age"\x0d\x0a\x0d\x0a),
  qq(34\x0d\x0a),
  qq(-----------------------------9051914041544843365972754266--),
);

validate_request(
  {
    parameters => [
      {
        name             => 'age',
        type             => 'array',
        collectionFormat => 'multi',
        items            => {type => 'number'},
        in               => 'formData'
      },
      {name => 'too_cool', type => 'boolean', in => 'formData'},
      {name => 'x' => type => 'number', required => 1, default => 33, in => 'formData'},
    ]
  },
  sub {
    is "@_", "", "valid form";
    is_deeply $input, {age => [42, 34], too_cool => false, x => 33}, 'formData';
  }
);

validate_request(
  {parameters => [{name => 'filex', type => 'file', in => 'formData', required => true}]},
  sub {
    like "@_", qr{/filex: Missing property}, 'missing filex property';
    is_deeply $input, {}, 'nothing in input';
  }
);

# collectionFormat
make_request('application/json', qq([]));
validate_request(
  {
    parameters => [
      {name => 'x', in => 'query', type => 'integer'},
      {
        name             => 'c',
        in               => 'query',
        type             => 'array',
        collectionFormat => 'csv',
        items            => {type => 'integer'}
      },
    ]
  },
  sub { is_deeply $input, {x => 0, c => [3, 1, 2]}, 'collectionFormat' }
);

is_deeply $c->req->url->query->to_hash->{x}, 0, 'query is not appended';

# json body
make_request('application/json', qq([1,2,3]));
validate_request(
  {parameters => [{name => 'body', in => 'body', schema => {type => 'object'}}]},
  sub {
    like "@_", qr{/body: Expected object - got array}, 'expected object';
  }
);

make_request('application/json', qq({"age":42}));
validate_request(
  {parameters => [{name => 'body', in => 'body', schema => {type => 'object'}}]},
  sub {
    is_deeply $input, {body => {age => 42}}, 'json body';
    is "@_", "", "valid json";
  }
);

# upload
make_request(
  qq(multipart/form-data; boundary=---------------------------9051914041544843365972754266),
  qq(-----------------------------9051914041544843365972754266\x0d\x0a),
  qq(Content-Disposition: form-data; name="data"; filename="a.txt"\x0d\x0a),
  qq(Content-Type: text/plain\x0d\x0a\x0d\x0a),
  qq(binarydata\x0d\x0a),
  qq(-----------------------------9051914041544843365972754266--),
);

validate_request(
  {parameters => [{name => 'data', type => 'file', in => 'formData', required => true}]},
  sub {
    is "@_", "", "valid upload";
    ok UNIVERSAL::can($input->{data}, 'slurp'), 'data can slurp' or diag $input->{data};
  }
);

validate_request(
  {parameters => [{name => 'filex', type => 'file', in => 'formData', required => true}]},
  sub {
    like "@_", qr{/filex: Missing property}, 'missing filex property';
    is_deeply $input, {}, 'nothing in input';
  }
);

# query
make_request('application/json', qq([]));
validate_request(
  {parameters => [{name => 'x', in => 'query', type => 'boolean'}]},
  sub { is_deeply $input, {x => false}, 'query with boolean' }
);


# colliding parameters should be resolved in M::P::OpenAPI
validate_request(
  {
    todo       => 'colliding parameters can be resolved by extracting them manually',
    parameters => [
      {name => 'x' => type => 'number', required => 1, default => 33, in => 'formData'},
      {name => 'x' => type => 'number', required => 1, in      => 'query'},
    ]
  },
  sub {
    is_deeply $input, {x => 33}, 'colliding parameters in form/query';
  }
);

# headers
$c->tx->req(Mojo::Message::Request->new)->req->headers->header('X-Custom' => 123)
  ->header('X-DATA' => 'something');
validate_request(
  {
    parameters => [
      {name => 'x-custom', type => 'integer', required => 1, in => 'header'},
      {name => 'X-Data',   type => 'string',  required => 1, in => 'header'},
    ]
  },
  sub {
    is "@_", "", "valid headers";
    is_deeply $input, {'x-custom' => 123, 'X-Data' => 'something'},
      'headers are correct and case insensitive';
  }
);

# missing header
make_request('application/json', qq([]));
validate_request(
  {parameters => [{name => 'x-custom', type => 'string', required => 1, in => 'header'}]},
  sub {
    like "@_", qr{\Q/x-custom: Expected string - got null.\E}, "the header is missing";
  }
);

# Valid booleans
$c->tx->req(Mojo::Message::Request->new)
  ->req->url->parse('http://127.0.0.1/?a=&b=0&c=false&x=true&y=1&z=0');
validate_request(
  {parameters => [map { +{name => $_, type => 'boolean', in => 'query'} } qw(a b c x y z),],},
  sub {
    is "@_", "", "valid request";
    is_deeply $input, {a => false, b => false, c => false, x => true, y => true, z => false},
      'valid booleans';
  }
);

# Invalid booleans
$c->tx->req(Mojo::Message::Request->new)
  ->req->url->parse('http://127.0.0.1/?a=something&b=2&c=TRUE');
validate_request(
  {parameters => [map { +{name => $_, type => 'boolean', in => 'query'} } qw(a b c),],},
  sub {
    like "@_",
      qr{\Q/a: Expected boolean - got string. /b: Expected boolean - got string. /c: Expected boolean - got string.\E},
      "invalid request";
    is_deeply $input, {}, 'nothing in input';
  }
);

done_testing;

sub make_request {
  my ($content_type) = shift;
  my $length = length join '', @_;
  $c = Mojolicious::Controller->new(tx => ($tx = Mojo::Transaction::HTTP->new));
  $req = $c->tx->req(Mojo::Message::Request->new)->req;
  $req->parse(qq(POST /whatever?c=3,1,2&x=0 HTTP/1.1\x0d\x0a));
  $req->parse(qq(Content-Type: $content_type\x0d\x0a));
  $req->parse(qq(Content-Length: $length\x0d\x0a\x0d\x0a));
  $req->parse($_) for @_;
  ok $req->is_finished, "request $length is finished";
}

sub validate_request {
  my ($schema, $cb) = @_;
  local $TODO = delete $schema->{todo};
  $input = {};
  $cb->($openapi->validate_request($c, $schema, $input));
}
