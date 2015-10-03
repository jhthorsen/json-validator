package MyApp::Controller::Pet;
use Mojo::Base 'Mojolicious::Controller';

our $RES = [{id => 123, name => 'kit-cat'}];
our $CODE = 200;

sub list {
  my ($c, $args, $cb) = @_;
  $c->$cb($RES, $CODE);
}

sub show {
  my ($c, $args, $cb) = @_;
  $RES->{id} = $args->{petId};
  $c->$cb($RES, $CODE);
}

sub get {
  my ($c, $args, $cb) = @_;
  return $c->$cb('', 201) if $CODE eq '201';
  return $c->$cb($RES, $CODE);
}

sub add {
  my ($c, $args, $cb) = @_;
  $RES->{name} = $args->{data}{name} if ref $args->{data} eq 'HASH';
  $c->$cb($RES, $CODE);
}

sub update {
  my ($c, $args, $cb) = @_;
  $c->$cb($RES, $CODE);
}

1;
