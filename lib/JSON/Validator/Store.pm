package JSON::Validator::Store;
use Mojo::Base -base;

use Carp qw(confess);
use Mojo::File qw(path);
use Mojo::URL;
use Mojo::Util qw(sha1_sum);
use JSON::Validator::Util qw(data_section);
use Scalar::Util qw(blessed);

use constant CASE_TOLERANT   => File::Spec->case_tolerant;
use constant DEBUG           => $ENV{JSON_VALIDATOR_DEBUG} || 0;
use constant RECURSION_LIMIT => $ENV{JSON_VALIDATOR_RECURSION_LIMIT} || 100;
use constant YAML_SUPPORT    => eval 'use YAML::XS 0.67;1';

my $BUNDLED = path(__FILE__)->sibling('cache');

has cache_paths =>
  sub { [split(/:/, $ENV{JSON_VALIDATOR_CACHE_PATH} || ''), $BUNDLED] };
has schemas => sub { +{} };

has ua => sub {
  require Mojo::UserAgent;
  my $ua = Mojo::UserAgent->new;
  $ua->proxy->detect;
  $ua->max_redirects(3);
  $ua;
};

sub add_schema {
  my ($self, $id, $schema) = @_;
  $id = "file://$id" if blessed $id and $id->isa('Mojo::File');
  $id =~ s!(.)#$!$1!;
  $self->schemas->{$id} = $schema;
  return $self;
}

sub get_schema {
  my ($self, $id) = @_;
  $id = sprintf "file://%s", join '/', @$id
    if blessed $id and $id->isa('Mojo::File');
  return $self->schemas->{$id};
}

sub id_obj {
  my ($self, $url) = ($_[0], "$_[1]");
  $url =~ s/#$//;
  return Mojo::URL->new($url) if $url =~ m!^(data|https?)://!;

  my $file = $self->_url_to_file($url);
  return CASE_TOLERANT ? path(lc $file) : $file if $file and -e $file;

  # Fallback
  return Mojo::URL->new($url);
}

sub load_schema {
  my ($self, $url) = @_;
  return $self->load_schema_from_text($url)         if ref $url eq 'SCALAR';
  return $self->load_schema_from_url($url)          if $url =~ m!^https?://!;
  return $self->load_schema_from_data_section($url) if $url =~ m!^data://!;
  return $self->load_schema_from_text(\$url)
    if $url =~ m!^\s*(?:[\[\{]|---\r?\n)!;

  my $file = $self->_url_to_file($url);
  return $self->load_schema_from_file($url) if $file and -f $file;

  return $self->load_schema_from_url($url)
    if $url =~ m!^/! and $self->ua->server->app;

  confess "Unable to load schema '$url' ($file)";
}

sub load_schema_from_data_section {
  my ($self,  $url)  = @_;
  my ($class, $file) = $url =~ m!^data://([^/]*)/(.*)!;
  warn "[JSON::Validator] Loading schema from data section: $url\n" if DEBUG;
  return $self->_load_schema_from_text(
    \data_section($class, $file, {confess => 1, encoding => 'UTF-8'}));
}

sub load_schema_from_file {
  my $self = shift;
  my $path = $self->_url_to_file(shift);
  warn "[JSON::Validator] Loading schema from file: $path\n" if DEBUG;
  return $self->_load_schema_from_text(\$path->slurp);
}

sub load_schema_from_text {
  $_[0]->_load_schema_from_text(ref $_[1] eq 'SCALAR' ? $_[1] : \$_[1]);
}

sub load_schema_from_url {
  my $self       = shift;
  my $url        = Mojo::URL->new(shift)->fragment(undef);
  my $cache_path = $self->cache_paths->[0];
  my $cache_file = Mojo::Util::md5_sum("$url");

  for (@{$self->cache_paths}) {
    my $path = path $_, $cache_file;
    warn "[JSON::Validator] Looking for cached spec $path ($url)\n" if DEBUG;
    return $self->_load_schema_from_text(\$path->slurp)             if -r $path;
  }

  my $tx  = $self->ua->get($url);
  my $err = $tx->error && $tx->error->{message};
  confess "[JSON::Validator] GET $url == $err" if $err;

  if ($cache_path and $cache_path ne $BUNDLED and -w $cache_path) {
    $cache_file = path $cache_path, $cache_file;
    warn "[JSON::Validator] Caching $url to $cache_file\n";
    $cache_file->spurt($tx->res->body);
  }

  return $self->_load_schema_from_text(\$tx->res->body);
}

sub _load_schema_from_text {
  my ($self, $text) = @_;
  warn "[JSON::Validator] Loading schema from string.\n" if DEBUG;

  # JSON
  return Mojo::JSON::decode_json($$text) if $$text =~ /^\s*\{/s;

  # YAML
  die "[JSON::Validator] YAML::XS 0.67 is missing or could not be loaded."
    unless YAML_SUPPORT;
  no warnings 'once';
  local $YAML::XS::Boolean = 'JSON::PP';
  return YAML::XS::Load($$text);
}

sub _url_to_file {
  my ($self, $file) = @_;
  return $file unless $file;
  $file =~ s!^file://!!;
  $file =~ s!#$!!;
  return path(split '/', $file)->realpath;
}

1;

=encoding utf8

=head1 NAME

JSON::Validator::Store - Store for JSON::Validator schemas

=head1 SYNOPSIS

  use JSON::Validator;

  my $jv = JSON::Validator->new;
  my $url = "http://json-schema.org/draft-07/schema";
  my $schema = $jv->store->load_schema($url);

  $jv->store->add_schema($url => $schema);
  warn Mojo::Util::dumper($jv->store->get_schema($url));

=head1 DESCRIPTION

L<JSON::Validator::Store> is a store for where raw schema data structures are
stored. This means the data in L</schemas> are hashes and I<not>
L<JSON::Validator::Schema> objects.

=head1 ATTRIBUTES

=head2 cache_paths

  $array_ref = $jvs->cache_paths;
  $jvs = $jvs->cache_paths(["/some/path"]);

Holds a list of paths to where to look for cached schemas on disk. The first
item will be used to store newly downloaded schemas, if the directory is
writable.

=head2 schemas

  $hash_ref = $jvs->schemas;
  $jvs = $jvs->schemas({$id => $hash_ref, ...});

Holds all the schemas. You probably want to use L</get_schema> and
L</add_schema> instead of this attribute directly.

=head2 ua

  $ua = $jvs->ua;
  $jvs = $jvs->ua(Mojo::UserAgent->new);

Holds a L<Mojo::UserAgent> object used to retrieve schemas from URLs.

=head1 METHODS

=head2 add_schema

  $jvs->add_schema($id => $hash_ref);

Will add a schema to the store. C<$id> is often the "$id" or "id" field in the
C<$hash_ref> (schema), but can be any string.

=head2 get_schema

  $hash_ref = $jvs->get_schema($id);

Used to retrieve a stored schema.

=head2 id_obj

  $obj = $jvs->id_obj($str);
  $obj = $jvs->id_obj($file);
  $obj = $jvs->id_obj($url);

Will return a L<Mojo::File> or L<Mojo::URL>.

This method is EXPERIMENTAL and will probably change without warning.

=head2 load_schema

  $hash_ref = $self->load_schema($url);
  $hash_ref = $self->load_schema($file);
  $hash_ref = $self->load_schema($text);

Will look at C<$url> and call one of the other "load_" methods below. Note that
none of the "load_" methods will call L</add_schema>.

=head2 load_schema_from_data_section

  $hash_ref = $self->load_schema_from_data_section("data://package_name/asset_name");

Loads schema from a Perl module, using L<JSON::Validator::Util/data_section>.

=head2 load_schema_from_file

  $hash_ref = $self->load_schema_from_data_section("/path/to/file");

Loads schema from a file on disk.

=head2 load_schema_from_text

  $hash_ref = $self->load_schema_from_text("{...}");
  $hash_ref = $self->load_schema_from_text("---\n...");

Parses the input text as either JSON or YAML.

=head2 load_schema_from_url

  $hash_ref = $self->load_schema_from_url($url);

Loads schema from a remote URL or a relative URL that can be fetched from
L<Mojo::UserAgent/server>.

=head1 SEE ALSO

L<JSON::Validator>.

=cut
