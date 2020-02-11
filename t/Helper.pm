package t::Helper;
use Mojo::Base -base;

use JSON::Validator;
use Mojo::JSON 'encode_json';
use Mojo::Util 'monkey_patch';
use Test::More;

$ENV{TEST_VALIDATOR_CLASS} = 'JSON::Validator';

sub edj {
  return Mojo::JSON::decode_json(Mojo::JSON::encode_json(@_));
}

sub joi_ok {
  my ($data, $joi, @expected) = @_;
  my $description
    ||= @expected ? "errors: @expected" : "valid: " . encode_json($data);
  my @errors = JSON::Validator::joi($data, $joi);
  Test::More::is_deeply(
    [map { $_->TO_JSON } sort { $a->path cmp $b->path } @errors],
    [map { $_->TO_JSON } sort { $a->path cmp $b->path } @expected],
    $description)
    or Test::More::diag(encode_json(\@errors));
}

sub jv { state $obj = $ENV{TEST_VALIDATOR_CLASS}->new }

sub validate_ok {
  my ($data, $schema, @expected) = @_;
  my $description
    ||= @expected ? "errors: @expected" : "valid: " . encode_json($data);
  my @errors = jv()->schema($schema)->validate($data);
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  Test::More::is_deeply(
    [map { $_->TO_JSON } sort { $a->path cmp $b->path } @errors],
    [map { $_->TO_JSON } sort { $a->path cmp $b->path } @expected],
    $description)
    or Test::More::diag(encode_json(\@errors));
}

sub import {
  my $class  = shift;
  my $caller = caller;

  eval "package $caller; use Test::Deep; use Test::More; 1" or die $@;
  $_->import for qw(strict warnings);
  feature->import(':5.10');

  monkey_patch $caller => E            => \&JSON::Validator::E;
  monkey_patch $caller => done_testing => \&Test::More::done_testing;
  monkey_patch $caller => edj          => \&edj;
  monkey_patch $caller => false        => \&Mojo::JSON::false;
  monkey_patch $caller => joi_ok       => \&joi_ok;
  monkey_patch $caller => jv           => \&jv;
  monkey_patch $caller => true         => \&Mojo::JSON::true;
  monkey_patch $caller => validate_ok  => \&validate_ok;
}

1;
