use lib '.';
use t::Helper;
use Test::More;

plan skip_all => 'Cpanel::JSON::XS and Mojo::JSON::MaybeXS is required.'
  unless eval 'require Cpanel::JSON::XS;require Mojo::JSON::MaybeXS;1';

validate_ok {disabled => Mojo::JSON->true},
  {properties => {disabled => {type => 'boolean'}}};
validate_ok {disabled => Mojo::JSON->false},
  {properties => {disabled => {type => 'boolean'}}};

done_testing;
