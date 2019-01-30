use lib '.';
use t::Helper;
use Test::More;

plan skip_all => 'This test require Cpanel::JSON::XS'
  unless eval 'require Cpanel::JSON::XS;1';

validate_ok {disabled => Mojo::JSON->true},
  {properties => {disabled => {type => 'boolean'}}};
validate_ok {disabled => Mojo::JSON->false},
  {properties => {disabled => {type => 'boolean'}}};

done_testing;
