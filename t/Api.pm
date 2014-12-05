package t::Api;
use Mojo::Base 'Mojolicious::Controller';

our $RES = {};

sub list_pets_get {
  my ($c, $args, $cb) = @_;
  $c->$cb($RES);
}

1;
