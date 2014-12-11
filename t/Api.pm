package t::Api;
use Mojo::Base 'Mojolicious::Controller';

our $RES = {};

sub list_pets_get {
  my ($c, $args, $cb) = @_;
  $c->$cb($RES);
}

sub show_pet_by_id_get {
  shift->list_pets_get(@_);
}

1;
