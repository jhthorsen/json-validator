package JSON::Validator::Store;
use Mojo::Base -base;

use Mojo::Exception;
use Mojo::File qw(path);
use Mojo::JSON;
use Mojo::JSON::Pointer;
use Mojo::UserAgent;
use Mojo::Util qw(url_unescape);
use JSON::Validator::Schema;
use JSON::Validator::URI qw(uri);
use JSON::Validator::Util qw(data_section str2data);

use constant DEBUG         => $ENV{JSON_VALIDATOR_DEBUG} && 1;
use constant BUNDLED_PATH  => path(path(__FILE__)->dirname, 'cache')->to_string;
use constant CASE_TOLERANT => File::Spec->case_tolerant;

die $@ unless eval q(package JSON::Validator::Exception; use Mojo::Base 'Mojo::Exception'; 1);

has cache_paths => sub { [split(/:/, $ENV{JSON_VALIDATOR_CACHE_PATH} || ''), BUNDLED_PATH] };
has schemas     => sub { +{} };

has ua => sub {
  my $ua = Mojo::UserAgent->new;
  $ua->proxy->detect;
  return $ua->max_redirects(3);
};

sub add {
  my ($self, $id, $schema) = @_;
  $id =~ s!(.)#$!$1!;
  $self->schemas->{$id} = $schema;
  return $id;
}

sub exists {
  my ($self, $id) = @_;
  return undef unless defined $id;
  $id =~ s!(.)#$!$1!;
  return $self->schemas->{$id} && $id;
}

sub get {
  my ($self, $id) = @_;
  return undef unless defined $id;
  $id =~ s!(.)#$!$1!;
  return $self->schemas->{$id};
}

sub load {
  return
       $_[0]->_load_from_url($_[1])
    || $_[0]->_load_from_data($_[1])
    || $_[0]->_load_from_text($_[1])
    || $_[0]->_load_from_file($_[1])
    || $_[0]->_load_from_app($_[1])
    || $_[0]->get($_[1])
    || _raise(qq(Unable to load schema "$_[1]".));
}

sub resolve {
  my ($self, $ref, $curr) = @_;
  $curr //= {base_url => ''};

  my ($base_url, $fragment) = split '#', $ref;
  my $abs_url = uri($base_url)->fragment($fragment);
  $abs_url  = uri $abs_url, $curr->{base_url} if $curr->{base_url} and !$abs_url->is_abs;
  $fragment = '' unless defined $fragment;
  $base_url ||= $curr->{base_url} || '';

  warn "[JSON::Validator] Resolve curr: ref=$ref,@{[map qq($_=$curr->{$_}), sort keys %$curr]}\n" if DEBUG;

  my $state = {base_url => $base_url, fragment => $fragment, source => 'unknown'};
  if (defined(my $schema = $self->schemas->{$abs_url})) {
    @$state{qw(base_url id root schema source)} = ($abs_url, $abs_url, $schema, $schema, 'schema/abs_url');
  }
  elsif (defined(my $root = $self->schemas->{$base_url})) {
    @$state{qw(base_url id root source)} = ($base_url, $base_url, $root, 'schema/base_url');
  }
  elsif ($base_url) {
    $base_url = uri $base_url, $curr->{base_url} if $curr->{base_url};
    my $id = $self->load($base_url);
    @$state{qw(base_url id root source)} = ($id, $id, $self->get($id), 'load');
    $state->{root} = $self->get($id);
  }
  else {
    @$state{qw(id root source)} = ('', $curr->{root}, 'root');
  }

  $fragment =~ s!%2f!~1!;    # /
  $fragment =~ s!%7e!~0!;    # ~
  $fragment = url_unescape $fragment;
  $state->{schema} //= length $fragment ? Mojo::JSON::Pointer->new($state->{root})->get($fragment) : $state->{root};
  _raise(qq[Unable to resolve "$ref" from "$state->{base_url}". ($state->{source})]) unless defined $state->{schema};

  $state->{$_} //= $curr->{$_} for keys %$curr;    # pass on original information
  warn "[JSON::Validator] Resolve state: @{[map qq($_=$state->{$_}), sort keys %$state]}\n" if DEBUG;
  return $state;
}

sub _add {
  my ($self, $id, $schema) = @_;
  $id = $self->add($id => $schema);

  if (ref $schema eq 'HASH') {
    return
        $schema->{'$id'} ? $self->add($schema->{'$id'} => $schema)
      : $schema->{id}    ? $self->add($schema->{id} => $schema)
      :                    $id;
  }

  return $id;
}

sub _load_from_app {
  return undef unless $_[1] =~ m!^/!;

  my ($self, $url) = @_;
  my $id;
  return undef unless $self->ua->server->app;
  return $id if $id = $self->exists($url);

  my $tx  = $self->ua->get($url);
  my $err = $tx->error && $tx->error->{message};
  _raise("GET $url: $err")                      if $err;
  warn "[JSON::Validator] Load from app $url\n" if DEBUG;
  return $self->_add($url => str2data $tx->res->body);
}

sub _load_from_data {
  return undef unless $_[1] =~ m!^data://([^/]*)/(.*)!;

  my ($self, $url) = @_;
  my $id;
  return $id if $id = $self->exists($url);

  my ($class, $file) = ($1, $2);    # data://([^/]*)/(.*)
  my $text = data_section $class, $file, {encoding => 'UTF-8'};
  _raise("Could not find $url") unless $text;
  warn "[JSON::Validator] Load from data $file in $class\n" if DEBUG;
  return $self->_add($url => str2data $text);
}

sub _load_from_file {
  my ($self, $file) = @_;

  $file =~ s!^file://!!;
  $file =~ s!#$!!;
  $file = path(split '/', url_unescape $file);
  return undef unless -e $file;

  $file = $file->realpath;
  my $id = uri()->new->scheme('file')->host('')->path(CASE_TOLERANT ? lc $file : "$file");
  warn "[JSON::Validator] Load from file $file\n" if DEBUG;
  return $self->exists($id) || $self->_add($id => str2data $file->slurp);
}

sub _load_from_text {
  my ($self, $text) = @_;
  my $is_scalar_ref = ref $text eq 'SCALAR';
  return undef unless $is_scalar_ref or $text =~ m!^\s*(?:---|\{)!s;

  my $id = uri->from_data($is_scalar_ref ? $$text : $text);
  warn "[JSON::Validator] Load from text $id\n" if DEBUG;
  return $self->exists($id) || $self->_add($id => str2data $is_scalar_ref ? $$text : $text);
}

sub _load_from_url {
  return undef unless $_[1] =~ m!^https?://!;

  my ($self, $url) = @_;
  my $id;
  return $id if $id = $self->exists($url);

  $url = uri($url)->fragment(undef);
  return $id if $id = $self->exists($url);

  my $cache_path = $self->cache_paths->[0];
  my $cache_file = Mojo::Util::md5_sum("$url");
  for (@{$self->cache_paths}) {
    my $path = path $_, $cache_file;
    warn "[JSON::Validator] Load from cache $path\n"  if DEBUG and -r $path;
    return $self->_add($url => str2data $path->slurp) if -r $path;
  }

  my $tx  = $self->ua->get($url);
  my $err = $tx->error && $tx->error->{message};
  _raise("GET $url: $err") if $err;

  if ($cache_path and $cache_path ne BUNDLED_PATH and -w $cache_path) {
    $cache_file = path $cache_path, $cache_file;
    $cache_file->spurt($tx->res->body);
  }

  warn "[JSON::Validator] Load from URL $url\n" if DEBUG;
  return $self->_add($url => str2data $tx->res->body);
}

sub _raise { die JSON::Validator::Exception->new(@_)->trace }

1;

=encoding utf8

=head1 NAME

JSON::Validator::Store - Load and caching JSON schemas

=head1 SYNOPSIS

  use JSON::Validator;
  my $jv = JSON::Validator->new;
  $jv->store->add("urn:uuid:ee564b8a-7a87-4125-8c96-e9f123d6766f" => {...});
  $jv->store->load("http://api.example.com/my/schema.json");

=head1 DESCRIPTION

L<JSON::Validator::Store> is a class for loading and caching JSON-Schemas.

=head1 ATTRIBUTES

=head2 cache_paths

  my $store     = $store->cache_paths(\@paths);
  my $array_ref = $store->cache_paths;

A list of directories to where cached specifications are stored. Defaults to
C<JSON_VALIDATOR_CACHE_PATH> environment variable and the specs that is bundled
with this distribution.

C<JSON_VALIDATOR_CACHE_PATH> can be a list of directories, each separated by ":".

See L<JSON::Validator/Bundled specifications> for more details.

=head2 schemas

  my $hash_ref = $store->schemas;
  my $store = $store->schemas({});

Hold the schemas as data structures. The keys are schema "id".

=head2 ua

  my $ua    = $store->ua;
  my $store = $store->ua(Mojo::UserAgent->new);

Holds a L<Mojo::UserAgent> object, used by L</schema> to load a JSON schema
from remote location.

The default L<Mojo::UserAgent> will detect proxy settings and have
L<Mojo::UserAgent/max_redirects> set to 3.

=head1 METHODS

=head2 add

  my $normalized_id = $store->add($id => \%schema);

Used to add a schema data structure. Note that C<$id> might not be the same as
C<$normalized_id>.

=head2 exists

  my $normalized_id = $store->exists($id);

Returns a C<$normalized_id> if it is present in the L</schemas>.

=head2 get

  my $schema = $store->get($normalized_id);

Used to retrieve a C<$schema> added by L</add> or L</load>.

=head2 load

  my $normalized_id = $store->load('https://...');
  my $normalized_id = $store->load('data://main/foo.json');
  my $normalized_id = $store->load('---\nid: yaml');
  my $normalized_id = $store->load('{"id":"yaml"}');
  my $normalized_id = $store->load(\$text);
  my $normalized_id = $store->load('/path/to/foo.json');
  my $normalized_id = $store->load('file:///path/to/foo.json');
  my $normalized_id = $store->load('/load/from/ua-server-app');

Can load a C<$schema> from many different sources. The input can be a string or
a string-like object, and the L</load> method will try to resolve it in the
order listed in above.

Loading schemas from C<$text> will generate an C<$normalized_id> in L</schemas>
looking like "urn:text:$text_checksum". This might change in the future!

Loading files from disk will result in a C<$normalized_id> that always start
with "file://".

Loading can also be done with relative path, which will then load from:

  $store->ua->server->app;

This method is EXPERIMENTAL, but unlikely to change significantly.

=head2 resolve

  $hash_ref = $store->resolve($url, \%defaults);

Takes a C<$url> (can also be a file, urn, ...) with or without a fragment and
returns this structure about the schema:

  {
    base_url => $str,  # the part before the fragment in the $url
    fragment => $str,  # fragment part of the $url
    id       => $str,  # store ID
    root     => ...,   # the root schema
    schema   => ...,   # the schema inside "root" if fragment is present
  }

This method is EXPERIMENTAL and can change without warning.

=head1 SEE ALSO

L<JSON::Validator>.

=cut
