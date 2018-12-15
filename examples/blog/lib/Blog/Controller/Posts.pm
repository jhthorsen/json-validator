package Blog::Controller::Posts;
use Mojo::Base 'Mojolicious::Controller';

use JSON::Validator 'joi';
use Mojo::JSON qw(false true);

sub create { shift->render(post => {}) }

# GET /posts/2018-12-11-1544489723-70142/edit
sub edit {
  my $self = shift;
  return $self->reply->not_found
    unless my $post = $self->posts->find($self->param('id'));
  return $self->render(post => $post);
}

# GET /posts
# GET /posts.json
sub index {
  my $self  = shift;
  my @posts = reverse @{$self->posts->all};
  $self->_validate_post($_) for @posts;
  $self->respond_to(
    json => {json  => {posts => \@posts}},
    any  => {posts => \@posts}
  );
}

# DELETE /posts/2018-12-11-1544489723-70142.json
sub remove {
  my $self = shift;
  $self->render(json =>
      {removed => $self->posts->remove($self->param('id')) ? true : false});
}

# GET /posts/2018-12-11-1544489723-70142
# GET /posts/2018-12-11-1544489723-70142.json
sub show {
  my $self = shift;
  return $self->reply->not_found
    unless my $post = $self->posts->find($self->param('id'));
  $self->_validate_post($post);
  return $self->respond_to(json => {json => $post}, any => {post => $post});
}

# POST /posts.json
sub store {
  my $self = shift;

  my @errors = $self->_validate_post;
  return $self->render(json => {errors => \@errors}, status => 400) if @errors;

  my $id = $self->posts->add($self->req->json);
  $self->render(json => {id => $id});
}

# POST /posts/2018-12-11-1544489723-70142.json
sub update {
  my $self = shift;

  my @errors = $self->_validate_post;
  return $self->render(json => {errors => \@errors}, status => 400) if @errors;

  my $id = $self->param('id');
  $self->posts->save($id, $self->req->json);
  $self->render(json => {id => $id});
}

# This method is used to both validate input, but also make sure the output
# JSON contains the correct boolean and number types. Example:
# {"published":"true"} and {"published":true} is not the same in JSON.
sub _validate_post {
  my $c = shift;
  my $post = shift || $c->req->json;

  return joi(
    $post,
    joi->object->props(
      author    => joi->email->required,
      body      => joi->string->min(1)->required,
      id        => joi->string->regex(qr{^\d+-\d+-\d+-\d+-\d+$}),
      published => joi->boolean->required,
      tags      => joi->array->items(joi->string),
      title     => joi->string->required->min(1)->regex(qr{^[^\n\r]+$}),
      updated   => joi->number,
    )
  );
}

1;
