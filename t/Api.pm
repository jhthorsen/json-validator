package t::Api;
use Mojo::Base 'Mojolicious::Controller';

our $RES  = {};
our $CODE = 200;

sub boolean_in_url {
  my ($c, $args, $cb) = @_;
  $c->$cb({p1 => $args->{p1}, q1 => $args->{q1}});
}

sub list_pets {
  my ($c, $args, $cb) = @_;
  $c->$cb($RES, $CODE);
}

sub show_pet_by_id {
  my $self = shift;
  $RES->{id} = $self->param('petId');
  $self->list_pets(@_);
}

sub add_pet {
  shift->list_pets(@_);
}

sub update_pet {
  shift->list_pets(@_);
}

1;
