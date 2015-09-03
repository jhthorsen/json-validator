package Blog::Controller::Posts;
use Mojo::Base 'Mojolicious::Controller';

sub create { shift->stash(post => {}) }

sub edit {
  my $self = shift;    # Web request
  $self->stash(post => $self->posts->find($self->param('id')));
}

sub list {
  my ($self, $args, $cb) = @_;

  if ($cb) {           # Swagger2 request
    $self->$cb($self->posts->all, 200);
  }
  else {               # Web request
    $self->render(posts => $self->posts->all);
  }
}

sub remove {
  my ($self, $args, $cb) = @_;

  if ($cb) {           # Swagger2 request
    $self->posts->remove($args->{id});
    $self->$cb({}, 200);
  }
  else {               # Web request
    $self->posts->remove($self->param('id'));
    $self->redirect_to('posts');
  }
}

sub show {
  my ($self, $args, $cb) = @_;

  if ($cb) {           # Swagger2 request
    my $entry = $self->posts->find($args->{id});
    return $self->$cb($entry, 200) if $entry;
    return $self->$cb({errors => [{message => 'Blog post not found.', path => '/id'}]}, 404);
  }
  else {               # Web request
    $self->render(post => $self->posts->find($self->param('id')));
  }
}

sub store {
  my ($self, $args, $cb) = @_;
  my $validation = $self->_validation($args->{entry});

  if ($cb) {           # Swagger2 request
    my $failed = $validation->failed;
    return $self->$cb({errors => [map { +{message => 'Invalid value.', path => "/$_"} } @$failed]}, 400) if @$failed;
    my $id = $self->posts->add($validation->output);
    return $self->$cb({id => $id}, 200);
  }
  else {               # Web request
    return $self->render(action => 'create', post => {}) if $validation->has_error;
    my $id = $self->posts->add($validation->output);
    return $self->redirect_to('show_post', id => $id);
  }
}

sub update {
  my ($self, $args, $cb) = @_;
  my $validation = $self->_validation($args->{entry});

  if ($cb) {           # Swagger2 request
    $self->posts->save($args->{id}, $validation->output);
    return $self->$cb({}, 200);
  }
  else {               # Web request
    return $self->render(action => 'edit', post => {}) if $validation->has_error;
    my $id = $self->param('id');
    $self->posts->save($id, $validation->output);
    $self->redirect_to('show_post', id => $id);
  }
}

sub _validation {
  my ($self, $input) = @_;

  my $validation = $self->validation;
  $validation->input($input) if $input;
  $validation->required('title');
  $validation->required('body');

  return $validation;
}

1;
