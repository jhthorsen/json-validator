package t::Api;
use Mojo::Base 'Mojolicious::Controller';

our $ERR;
our $RES  = {};
our $CODE = 200;

sub add_image {
  my ($c, $args, $cb) = @_;
  $c->$cb($args->{data}->slurp, $CODE);
}

sub authenticate {
  my ($next, $c, $config) = @_;
  return $next->($c) if $CODE == 200;
  return $c->render(json => $config, status => $CODE);
}

sub collection_format {
  my ($c, $args, $cb) = @_;
  $c->$cb($args, $CODE);
}

sub empty {
  my ($c, $args, $cb) = @_;
  $c->$cb('', $CODE);
}

sub get_headers {
  my ($c, $args, $cb) = @_;

  $c->res->headers->header('what-ever' => delete $RES->{header});
  $c->res->headers->header('x-bool' => $args->{'x-bool'}) if exists $args->{'x-bool'};
  $c->$cb($args, 200);
}

sub multi_param {
  my ($c, $args, $cb) = @_;
  $c->$cb($args, 200);
}

sub test_file {
  my ($c, $args, $cb) = @_;
  $c->$cb($c->stash('swagger')->pod->to_string, 200);
}

sub boolean_in_url {
  my ($c, $args, $cb) = @_;
  $c->$cb({p1 => $args->{p1}, q1 => $args->{q1}});
}

sub ip_in_url {
  my ($c, $args, $cb) = @_;
  $c->$cb({ip => $args->{ip}});
}

sub list_pets {
  my ($c, $args, $cb) = @_;
  $c->$cb($RES, $CODE);
}

sub status {
  my ($c, $args, $cb) = @_;
  my $resp = {};
  $resp->{status} = $RES;
  $c->$cb($resp, $CODE);
}

sub show_pet_by_id {
  my ($c, $args, $cb) = @_;
  $RES->{id} = $args->{petId};
  $c->$cb($RES, $CODE);
}

sub get_pet {
  my ($c, $args, $cb) = @_;
  die $ERR if $ERR;
  return $c->$cb('', 201) if $CODE == 201;
  return $c->$cb($RES, $CODE);
}

sub add_pet {
  my ($c, $args, $cb) = @_;
  $RES->{name} = $args->{data}{name} if ref $args->{data} eq 'HASH';
  $c->$cb($RES, $CODE);
}

sub update_pet {
  my ($c, $args, $cb) = @_;
  $c->$cb($RES, $CODE);
}

sub patch_pet {
  my ($c, $args, $cb) = @_;
  $c->$cb({}, 204);
}

sub json_patch_pet {
  my ($c, $args, $cb) = @_;
  $c->$cb($RES, 226);
}

sub with_defaults {
  my ($c, $args, $cb) = @_;
  $c->$cb({ip => $args->{ip}, x => $args->{x}});
}

sub import {
  strict->import;
  warnings->import;
}

1;
