package t::Helper;
use Mojo::Base -base;

use JSON::Validator;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util qw(monkey_patch);
use Test::More;

$ENV{TEST_VALIDATOR_CLASS} = 'JSON::Validator';

sub acceptance {
  my ($class, $schema_class, %acceptance_params) = @_;

  Test::More::plan(skip_all => 'cpanm Test::JSON::Schema::Acceptance')
    unless eval 'require Test::JSON::Schema::Acceptance;1';
  Test::More::plan(skip_all => $@) unless eval "require $schema_class;1";

  $acceptance_params{todo_tests}
    = [map { +{file => $_->[0], group_description => $_->[1], test_description => $_->[2]}; }
      @{$acceptance_params{todo_tests}}]
    if $acceptance_params{todo_tests};

  my $specification = $schema_class =~ m!::(\w+)$! ? lc $1 : 'unknown';
  $specification = 'draft2019-09' if $specification eq 'draft201909';
  Test::JSON::Schema::Acceptance->new(specification => $specification)->acceptance(
    %acceptance_params,
    validate_data => sub {
      my ($schema_p, $data_p) = map { Mojo::JSON::Pointer->new(shift @_) } qw(schema data);
      my ($schema,   $data)   = map { clone($_->data) } $schema_p, $data_p;
      my $valid = $schema_class->new($schema)->validate($data) ? 0 : 1;

      # Doing internal tests on mutation, since I think Test::JSON::Schema::Acceptance is a bit too strict
      Test2::Tools::Compare::is(encode_json($data),   encode_json($data_p->data),   'data structure is the same');
      Test2::Tools::Compare::is(encode_json($schema), encode_json($schema_p->data), 'schema structure is the same')
        unless _acceptance_schema_contains_invalid_ref($schema_p);

      return $valid;
    },
  );
}

sub clone {
  return decode_json(encode_json($_[0]));
}

sub edj {
  return Mojo::JSON::decode_json(Mojo::JSON::encode_json(@_));
}

sub joi_ok {
  my ($data, $joi, @expected) = @_;
  my $description ||= @expected ? "errors: @expected" : "valid: " . encode_json($data);
  my @errors = JSON::Validator::Joi->new($joi)->validate($data);
  Test::More::is_deeply([map { $_->TO_JSON } sort { $a->path cmp $b->path } @errors],
    [map { $_->TO_JSON } sort { $a->path cmp $b->path } @expected], $description)
    or Test::More::diag(encode_json(\@errors));
}

sub jv { state $obj = $ENV{TEST_VALIDATOR_CLASS}->new }

sub schema { state $schema; $schema = $_[1] if $_[1]; $schema }

sub schema_validate_ok {
  my ($data, $schema, @expected) = @_;
  my $description = @expected ? "errors: @expected" : "valid: " . encode_json($data);

  my @errors = t::Helper->schema->resolve($schema)->validate($data);
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  Test::More::is_deeply([map { $_->TO_JSON } sort { $a->path cmp $b->path } @errors],
    [map { $_->TO_JSON } sort { $a->path cmp $b->path } @expected], $description)
    or Test::More::diag(encode_json(\@errors));
}

sub test {
  my ($class, $category, @methods) = @_;
  my $test_class = "t::test::$category";
  eval "require $test_class;1" or die $@;
  (note("$category $_"), $test_class->$_) for @methods;
}

sub validate_ok {
  my ($data, $schema, @expected) = @_;
  my $description = @expected ? "errors: @expected" : "valid: " . encode_json($data);
  my @errors      = jv()->schema($schema)->validate($data);
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  Test::More::is_deeply([map { $_->TO_JSON } sort { $a->path cmp $b->path } @errors],
    [map { $_->TO_JSON } sort { $a->path cmp $b->path } @expected], $description)
    or Test::More::diag(encode_json(\@errors));
}

sub import {
  my $class  = shift;
  my $caller = caller;

  eval "package $caller; use Test::Deep; use Test::More; 1" or die $@;
  $_->import for qw(strict warnings);
  feature->import(':5.10');

  monkey_patch $caller => E                  => \&JSON::Validator::E;
  monkey_patch $caller => done_testing       => \&Test::More::done_testing;
  monkey_patch $caller => edj                => \&edj;
  monkey_patch $caller => false              => \&Mojo::JSON::false;
  monkey_patch $caller => joi_ok             => \&joi_ok;
  monkey_patch $caller => jv                 => \&jv;
  monkey_patch $caller => schema_validate_ok => \&schema_validate_ok;
  monkey_patch $caller => true               => \&Mojo::JSON::true;
  monkey_patch $caller => validate_ok        => \&validate_ok;
}

sub _acceptance_schema_contains_invalid_ref {
  my $p     = shift;
  my @paths = ('', '/properties/foo');

  # JSON::Validator always normalizes $ref with multiple keys
  for my $path (@paths) {
    my $ref = $p->get($path);
    return 1 if ref $ref eq 'HASH' && $ref->{'$ref'} && 1 != keys %$ref;
  }

  return 0;
}

1;
