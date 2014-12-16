package t::Api;
use Mojo::Base 'Mojolicious::Controller';

our $RES = {};

sub list_pets_get {
  my ($c, $args, $cb) = @_;
  $c->$cb($RES);
}

sub show_pet_by_id_get {
  my $self = shift;
  $RES->{id} = $self->param('petId');
  $self->list_pets_get(@_);
}

sub add_pet_post {
  my $self = shift;
  $RES->{body} = $self->req->body;
  $self->list_pets_get(@_);
}

sub update_pet_put {
  shift->list_pets_get(@_);
}

1;
