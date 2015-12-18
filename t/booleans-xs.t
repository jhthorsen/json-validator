BEGIN {
  $ENV{TEST_XS} = eval "require Cpanel::JSON::XS;require Mojo::JSON::MaybeXS;1";
}

use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

plan skip_all => 'Cpanel::JSON::XS and Mojo::JSON::MaybeXS is required.' unless $ENV{TEST_XS};

my $schema    = {properties => {disabled => {type => "boolean"}}};
my $validator = JSON::Validator->new->schema($schema);
my $objects   = [{disabled => 1}, {disabled => 0}];
my @errors;

for my $o (@$objects) {
  $o->{disabled} = $o->{disabled} ? Mojo::JSON->true : Mojo::JSON->false;
  @errors = $validator->validate($o);
  ok !@errors, "boolean via Mojo::JSON::MaybeXS ($o->{disabled}). (@errors)";
}

done_testing;
