use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use JSON::Validator::OpenAPI::Mojolicious;
use Mojo::File 'path';
use Mojo::JSON qw(encode_json decode_json);
use Mojolicious::Lite;

my $test_suite = path(qw(t openapi-tests v2));
plan skip_all => "Cannot find test files in $test_suite" unless -d $test_suite;

is JSON::Validator::OpenAPI::SPECIFICATION_URL(), 'http://swagger.io/v2/schema.json', 'spec url';

my $t = Test::Mojo->new;
my $host_port = $t->ua->server->url->host_port;

my $test_only_re = $ENV{TEST_ONLY} || '';
my $todo_re = join('|',
  'discriminator - missing property but default',
  'number float - not match',
);

for my $file (sort $test_suite->list->each) {
  for my $group (@{decode_json($file->slurp)}) {
    for my $test (@{$group->{tests}}) {
      my $schema = encode_json $group->{schema};
      my $descr  = "$group->{description} - $test->{description}";
      next if $test_only_re and $descr !~ /$test_only_re/;
      diag <<"HERE" if $test_only_re;
---
description:  $descr
schema:       $schema
data:         @{[encode_json $test->{data}]}
expect_valid: @{[$test->{valid} ? 'Yes' : 'No']}
HERE
      $schema =~ s!http\W+localhost:1234\b!http://$host_port!g;
      $schema = decode_json $schema;
      my $method = $test->{input} ? 'validate_input' : 'validate';
      my @errors = eval {
        my $openapi = JSON::Validator::OpenAPI::Mojolicious->new
          ->schema($schema) # needed because validate_input relies on copying to $self->{root}
          ;
        my $subschema = $test->{schemapointer}
          ? Mojo::JSON::Pointer->new($schema)->get($test->{schemapointer})
          : $schema;
        $openapi->ua($t->ua)->$method($test->{data}, $subschema);
      };
      my $e = $@ || join ', ', @errors;
      local $TODO = $descr =~ /$todo_re/ ? 'TODO' : undef;
      is
        $e ? 'invalid' : 'valid',
        $test->{valid} ? 'valid' : 'invalid',
        $descr
        or diag "Error: $e";
    }
  }
}

done_testing;
