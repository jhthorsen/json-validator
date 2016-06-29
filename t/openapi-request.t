use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Mojo::JSON 'true';
use Mojolicious::Controller;
use JSON::Validator::OpenAPI;

my $t  = Test::Mojo->new();
my $tx = Mojo::Transaction::HTTP->new;
my $c  = Mojolicious::Controller->new(tx => $tx);

my $openapi = JSON::Validator::OpenAPI->new;
my ($schema, @errors, %input);

my $req = $tx->req;
$req->parse(qq(POST /image HTTP/1.1\x0d\x0a));
$req->parse(
  qq(Content-Type: multipart/form-data; boundary=---------------------------9051914041544843365972754266\x0d\x0a)
);
$req->parse(qq(Content-Length: 221\x0d\x0a\x0d\x0a));
$req->parse(qq(-----------------------------9051914041544843365972754266\x0d\x0a));
$req->parse(qq(Content-Disposition: form-data; name="data"; filename="a.txt"\x0d\x0a));
$req->parse(qq(Content-Type: text/plain\x0d\x0a));
$req->parse(qq(\x0d\x0a));
$req->parse(qq(Image data\x0d\x0a));
$req->parse(qq(-----------------------------9051914041544843365972754266--));
is $req->content->progress, 221, 'progress';
ok $req->is_finished, 'request is finished';

$schema = {parameters => [{name => 'data', type => 'file', in => 'formData', required => true}]};
@errors = $openapi->validate_request($c, $schema, \%input);
is_deeply \@errors, [], 'valid request';
ok UNIVERSAL::can($input{data}, 'slurp'), 'data can slurp' or diag $input{data};

done_testing;
