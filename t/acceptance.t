use Mojo::Base -strict;
use JSON::Validator::Schema::Draft4;
use Mojo::File 'path';
use Mojo::JSON qw(encode_json decode_json false true);
use Test::Mojo;
use Test::More;

my $test_suite = path(qw(t draft4-tests));
my $remotes    = path(qw(t remotes));
plan skip_all => 'Cannot find test files in t/draft4-tests'
  unless -d $test_suite;

use Mojolicious::Lite;
app->static->paths(["$remotes"]);
my $t = Test::Mojo->new;
$t->get_ok('/integer.json')->status_is(200);
my $host_port = $t->ua->server->url->host_port;

my $test_only_re = $ENV{TEST_ONLY} || '';
my $todo_re      = join('|',
  'change resolution scope - changed scope ref valid',
  $ENV{TEST_ONLINE} ? () : ('remote ref'),
);

my $jv = JSON::Validator->new->ua($t->ua);
for my $file (sort $test_suite->list->each) {
  for my $group (@{decode_json($file->slurp)}) {
    for my $test (@{$group->{tests}}) {
      my $schema = encode_json $group->{schema};
      my $descr  = "$group->{description} - $test->{description}";

      next          if $test_only_re and $descr !~ /$test_only_re/;
      diag <<"HERE" if $test_only_re;
---
description:  $descr
schema:       $schema
data:         @{[encode_json $test->{data}]}
expect_valid: @{[$test->{valid} ? 'Yes' : 'No']}
HERE

      $schema =~ s!http\W+localhost:1234\b!http://$host_port!g;
      my @errors;
      eval {
        $schema
          = JSON::Validator::Schema::Draft4->new(decode_json($schema), %$jv);
        @errors = @{$jv->schema($schema)->schema->errors};
        @errors = $jv->validate($test->{data}) unless @errors;
      };

      my $e = $@ || join ', ', @errors;
      local $TODO = $descr =~ /$todo_re/ ? 'TODO' : undef;
      note "ERROR: $e" if $e;
      is $e ? 'invalid' : 'valid', $test->{valid} ? 'valid' : 'invalid', $descr;
    }
  }
}

done_testing();
