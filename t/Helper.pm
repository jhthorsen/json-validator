package t::Helper;
use Mojo::Base -base;

use Mojo::JSON 'encode_json';
use Mojo::Util 'monkey_patch';
use JSON::Validator;
use Test::More;

$ENV{TEST_VALIDATOR_CLASS} = 'JSON::Validator';

sub dump_validator {
  my $class = shift;
  my $jv = shift || $class->validator;
  local $Data::Dumper::Indent = 1;
  local $jv->{ua} = 'Mojo::UserAgent';
  Test::More::note(Data::Dumper::Dumper($jv));
}

sub edj {
  return Mojo::JSON::decode_json(Mojo::JSON::encode_json(@_));
}

sub joi_ok {
  my ($data, $joi, @expected) = @_;
  my $description ||= @expected ? "errors: @expected" : "valid: " . encode_json($data);
  my @errors = JSON::Validator::joi($data, $joi);
  Test::More::is_deeply([map { $_->TO_JSON } sort { $a->path cmp $b->path } @errors],
    [map { $_->TO_JSON } sort { $a->path cmp $b->path } @expected], $description)
    or Test::More::diag(encode_json(\@errors));
}

sub validate_ok {
  my ($data, $schema, @expected) = @_;
  my $description ||= @expected ? "errors: @expected" : "valid: " . encode_json($data);
  my @errors = validator()->schema($schema)->validate($data);
  Test::More::is_deeply([map { $_->TO_JSON } sort { $a->path cmp $b->path } @errors],
    [map { $_->TO_JSON } sort { $a->path cmp $b->path } @expected], $description)
    or Test::More::diag(encode_json(\@errors));
}

sub validator { state $obj = $ENV{TEST_VALIDATOR_CLASS}->new }

sub import {
  my $class  = shift;
  my $caller = caller;

  strict->import;
  warnings->import;
  monkey_patch $caller => E            => \&JSON::Validator::E;
  monkey_patch $caller => done_testing => \&Test::More::done_testing;
  monkey_patch $caller => false        => \&Mojo::JSON::false;
  monkey_patch $caller => edj          => \&edj;
  monkey_patch $caller => true         => \&Mojo::JSON::true;
  monkey_patch $caller => validate_ok  => \&validate_ok;
  monkey_patch $caller => joi_ok       => \&joi_ok;
}

1;
