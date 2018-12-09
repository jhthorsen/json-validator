package Blog::Model::Posts;
use Mojo::Base -base;

use Mojo::JSON qw(false true);
use Time::HiRes;

has format => 'markdown';
has 'storage';

sub add {
  my ($self, $post) = @_;

  my $time = Time::HiRes::time;
  my (@ymd) = (localtime $time)[5, 4, 3];
  $ymd[0] += 1900;
  $ymd[1] += 1;
  my $id = join '-', @ymd, split /\./, $time;
  my $path = $self->_id_to_path($id);

  local $post->{id} = $id;
  $path->dirname->make_path unless -d $path->dirname;
  $path->spurt($self->_serialize($post));

  return $id;
}

sub all {
  my $self = shift;
  return $self->storage->list_tree->sort->map(sub { $self->_deserialize(shift) });
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
  my $self = shift;
  my @ymd = split /-/, shift;
  my ($epoch, $ms) = (pop @ymd, pop @ymd);
  return $self->storage->child(@ymd, sprintf '%s-%s.%s', $epoch, $ms, $self->format);
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
