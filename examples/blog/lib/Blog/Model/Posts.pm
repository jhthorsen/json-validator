package Blog::Model::Posts;
use Mojo::Base -base;

use Mojo::JSON qw(false true);
use Time::HiRes;

has 'storage';

sub add {
  my ($self, $post) = @_;
  my $path;

  state $id = 0;
  while (1) {
    last unless -e ($path = $self->_id_to_path(++$id));
  }

  local $post->{id} = $id;
  $path->dirname->make_path unless -d $path->dirname;
  $path->spurt($self->_serialize($post));

  return $id;
}

sub all {
  my $self = shift;
  return $self->storage->list->sort->map(sub { $self->_deserialize(shift) });
}

sub find {
  my ($self, $id) = @_;
  return $self->_deserialize($self->_id_to_path($id));
}

sub remove {
  my ($self, $id) = @_;
  my $path = $self->_id_to_path($id);
  unlink $path or die "rm $path: $!" if -e $path;
}

sub save {
  my ($self, $id, $post) = @_;
  my $path = $self->_id_to_path($id);
  local $post->{id} = $id;
  return -e $path ? $path->spurt($self->_serialize($post)) : undef;
}

sub _deserialize {
  my ($self, $path) = @_;
  return undef unless -e $path and my $fh = $path->open('<');

  my %post;
  while (<$fh>) {
    last if /^---/ and %post;
    $post{$1} = $2 if /^(\w+):\s(.*)/;
  }

  $post{body} = join '', <$fh>;
  $post{published} = $post{published} eq 'true' ? true : false;
  $post{tags} = [split /\W+/, $post{tags} || ''];
  return \%post;
}

sub _id_to_path {
  my ($self, $id) = @_;
  return $self->storage->child("$id.markdown");
}

sub _serialize {
  my ($self, $post) = @_;
  local $post->{updated} = Time::HiRes::time;
  local $post->{published} = $post->{published} ? 'true' : 'false';

  my $meta = "---\n";
  $meta .= sprintf "%s: %s\n", $_, ref $post->{$_} eq 'ARRAY'
    ? join ',', @{$post->{$_}}
    : $post->{$_}
    for grep { $_ ne 'body' } sort keys %$post;

  return "$meta---\n$post->{body}";
}

1;
