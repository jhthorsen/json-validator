package Swagger2;

=head1 NAME

Swagger2 - Swagger RESTful API Documentation

=head1 VERSION

0.09

=head1 DESCRIPTION

THIS MODULE IS EXPERIMENTAL! ANY CHANGES CAN HAPPEN!

L<Swagger2> is a module for generating, parsing and transforming
L<swagger|http://swagger.io/> API documentation. It has support for reading
swagger specification in JSON notation and it can also read YAML files,
if a L</YAML parser> is installed.

This distribution comes with a L<Mojolicious> plugin,
L<Mojolicious::Plugin::Swagger2>, which can set up routes and perform input
and output validation.

=head1 RECOMMENDED MODULES

=over 4

=item * YAML parser

A L<YAML> parser is required if you want to read/write spec written in
the YAML format. Supported modules are L<YAML::XS>, L<YAML::Syck>, L<YAML>
and L<YAML::Tiny>.

=back

=head1 SYNOPSIS

  use Swagger2;
  my $swagger = Swagger2->new("file:///path/to/api-spec.yaml");

  # Access the raw specification values
  print $swagger->tree->get("/swagger");

  # Returns the specification as a POD document
  print $swagger->pod->to_string;

=cut

use Mojo::Base -base;
use Mojo::JSON qw( encode_json decode_json );
use Mojo::JSON::Pointer;
use Mojo::URL;
use Mojo::Util 'md5_sum';
use File::Spec;
use constant CACHE_DIR => $ENV{SWAGGER2_CACHE_DIR} || '';

our $VERSION = '0.09';

# Should be considered internal
our $SPEC_FILE = do {
  use File::Basename 'dirname';
  File::Spec->catfile(dirname(__FILE__), 'Swagger2', 'schema.json');
};

my @YAML_MODULES = qw( YAML::Tiny YAML YAML::Syck YAML::XS );
my $YAML_MODULE = $ENV{SWAGGER2_YAML_MODULE} || (grep { eval "require $_;1" } @YAML_MODULES)[0] || 'Swagger2::FALLBACK';

sub Swagger2::FALLBACK::Dump { die "Need to install a YAML module: @YAML_MODULES"; }
sub Swagger2::FALLBACK::Load { die "Need to install a YAML module: @YAML_MODULES"; }

Mojo::Util::monkey_patch __PACKAGE__, LoadYAML => eval "\\\&$YAML_MODULE\::Load";
Mojo::Util::monkey_patch __PACKAGE__, DumpYAML => eval "\\\&$YAML_MODULE\::Dump";

=head1 ATTRIBUTES

=head2 base_url

  $mojo_url = $self->base_url;

L<Mojo::URL> object that holds the location to the API endpoint.
Note: This might also just be a dummy URL to L<http://example.com/>.

=head2 specification

  $pointer = $self->specification;
  $self = $self->specification(Mojo::JSON::Pointer->new({}));

Holds a L<Mojo::JSON::Pointer> object containing the
L<Swagger 2.0 schema|https://github.com/swagger-api/swagger-spec>.

=head2 tree

  $pointer = $self->tree;
  $self = $self->tree(Mojo::JSON::Pointer->new({}));

Holds a L<Mojo::JSON::Pointer> object containing your API specification.

=head2 ua

  $ua = $self->ua;
  $self = $self->ua(Mojo::UserAgent->new);

A L<Mojo::UserAgent> used to fetch remote documentation.

=head2 url

  $mojo_url = $self->url;

L<Mojo::URL> object that holds the location to the documentation file.
This can be both a location on disk or an URL to a server. A remote
resource will be fetched using L<Mojo::UserAgent>.

=cut

has base_url => sub {
  my $self = shift;
  my $url  = Mojo::URL->new;
  my ($schemes, $v);

  $self->load if !$self->{tree} and '' . $self->url;
  $schemes = $self->tree->get('/schemes') || [];
  $url->host($self->tree->get('/host')     || 'example.com');
  $url->path($self->tree->get('/basePath') || '/');
  $url->scheme($schemes->[0]               || 'http');

  return $url;
};

has specification => sub {
  shift->_load(Mojo::URL->new($SPEC_FILE));
};

has tree => sub {
  my $self = shift;

  $self->load if '' . $self->url;
  $self->{tree} || Mojo::JSON::Pointer->new({});
};

has ua => sub {
  require Mojo::UserAgent;
  Mojo::UserAgent->new;
};

has _validator => sub {
  require Swagger2::SchemaValidator;
  Swagger2::SchemaValidator->new;
};

sub url { shift->{url} }

=head1 METHODS

=head2 expand

  $swagger = $self->expand;

This method returns a new C<Swagger2> object, where all the
L<references|https://tools.ietf.org/html/draft-zyp-json-schema-03#section-5.28>
are resolved.

=cut

sub expand {
  my $self     = shift;
  my $class    = Scalar::Util::blessed($self);
  my $expanded = $self->_resolve($self->tree, $self->url->clone->fragment(undef));

  $class->new(%$self)->tree($expanded);
}

=head2 load

  $self = $self->load;
  $self = $self->load($url);

Used to load the content from C<$url> or L</url>. This method will try to
guess the content type (JSON or YAML) by looking at the filename, URL path
or "Content-Type" header reported by a web server.

=cut

sub load {
  my $self = shift;
  delete $self->{base_url};
  $self->{url} = Mojo::URL->new(shift) if @_;
  $self->{tree} = $self->_load($self->url);
  $self;
}

=head2 new

  $self = Swagger2->new($url);
  $self = Swagger2->new(%attributes);
  $self = Swagger2->new(\%attributes);

Object constructor.

=cut

sub new {
  my $class = shift;
  my $url   = @_ % 2 ? shift : '';
  my $self  = $class->SUPER::new(url => $url, @_);

  $self->{url} = Mojo::URL->new($self->{url});
  $self;
}

=head2 pod

  $pod_object = $self->pod;

Returns a L<Swagger2::POD> object.

=cut

sub pod {
  my $self = shift;
  my $resolved = $self->_resolve($self->tree, $self->url->clone->fragment(undef));

  require Swagger2::POD;
  Swagger2::POD->new(base_url => $self->base_url, tree => $resolved);
}

=head2 to_string

  $json = $self->to_string;
  $json = $self->to_string("json");
  $yaml = $self->to_string("yaml");

This method can transform this object into Swagger spec.

=cut

sub to_string {
  my $self = shift;
  my $format = shift || 'json';

  if ($format eq 'yaml') {
    return DumpYAML($self->tree->data);
  }
  else {
    return encode_json $self->tree->data;
  }
}

=head2 validate

  @errors = $self->validate;

Will validate this object against the L</specification>,
and return a list with all the errors found. See also
L<Swagger2::SchemaValidator/validate>.

=cut

sub validate {
  my $self   = shift;
  my $schema = $self->_resolve($self->specification);

  return $self->_validator->validate($self->_resolve($self->tree)->data, $schema->data);
}

sub _load {
  my ($self, $url) = @_;
  my $namespace = $url->clone->fragment('');
  my $scheme = $url->scheme || 'file';
  my ($doc, $type);

  # already loaded into memory
  if ($self->{loaded}{$namespace}) {
    return $self->{loaded}{$namespace};
  }

  # try to read processed spec from file cache
  if (CACHE_DIR) {
    my $file = File::Spec->catfile(CACHE_DIR, md5_sum $namespace);
    if (-e $file) {
      $doc  = Mojo::Util::slurp($file);
      $type = 'json';
    }
  }

  # load spec from disk or web
  if (!CACHE_DIR or !$doc) {
    if ($scheme eq 'file') {
      $doc = Mojo::Util::slurp(File::Spec->catfile(split '/', $url->path));
      $type = lc $1 if $url->path =~ /\.(yaml|json)$/i;
    }
    else {
      my $tx = $self->ua->get($url);
      $doc  = $tx->res->body;
      $type = lc $1 if $url->path =~ /\.(\w+)$/;
      $type = lc $1 if +($tx->res->headers->content_type // '') =~ /(json|yaml)/i;
      Mojo::Util::spurt($doc, File::Spec->catfile(CACHE_DIR, md5_sum $namespace)) if CACHE_DIR;
    }

    $type ||= $doc =~ /^---/ ? 'yaml' : 'json';
  }

  # parse the document
  eval { $doc = $type eq 'yaml' ? LoadYAML($doc) : decode_json($doc); } or do {
    die "Could not load document from $url: $@ ($doc)";
  };

  $doc                           = Mojo::JSON::Pointer->new($doc);
  $self->{loaded}{$namespace}    = $doc;
  $self->{namespace}{$namespace} = $namespace;

  if (my $id = $doc->data->{id}) {
    $self->{loaded}{$id} = $self->{loaded}{$namespace};
    $self->{namespace}{id} = $namespace;
  }
  else {
    $doc->data->{id} = "$namespace";
  }

  return $doc;
}

sub _resolve {
  my ($self, $pointer, $namespace) = @_;
  my $out = {};

  local $self->{refs} = [];
  local $self->{seen} = {};
  $self->_resolve_deep($pointer, '', $out);
  $self->_resolve_refs(Mojo::URL->new($namespace || $pointer->get('/id')));

  return Mojo::JSON::Pointer->new($out);
}

sub _resolve_deep {
  my ($self, $pointer, $path, $out) = @_;
  my $in = $pointer->get($path);

  if (ref $in ne 'HASH') {
    return;
  }
  if (ref $in and $self->{seen}{$in}++) {
    return;
  }

  for my $name (keys %$in) {
    my $p = $name;
    $p =~ s!/!~1!g;
    if (ref $in->{$name} eq 'HASH') {
      $out->{$name} = {%{$in->{$name}}};
      $self->_track_ref($in->{$name}, $name, $out) and next;
      $self->_resolve_deep($pointer, "$path/$p", $out->{$name});
    }
    elsif (ref $in->{$name} eq 'ARRAY') {
      $out->{$name} = [];    # Fix "Not an ARRAY reference at lib/Swagger2.pm line 356."
      for my $i (0 .. @{$in->{$name}} - 1) {
        $out->{$name}[$i] = $in->{$name}[$i];
        $self->_resolve_deep($pointer, "$path/$p/$i", $out->{$name}[$i]);
      }
    }
    else {
      $out->{$name} = $in->{$name};
    }
  }
}

sub _resolve_refs {
  my ($self, $namespace) = @_;
  my $refs = $self->{refs};

  for (sort { length($b) <=> length($a) } @$refs) {
    my ($node, $key, $url) = @$_;
    my $doc = $self->_load(($url->host or $url->path->to_string) ? $url : $namespace);

    $key =~ s!~1!/!g;
    if (ref $node eq 'ARRAY') {
      $node->[$key] = $doc->get($url->fragment);
    }
    else {
      $node->{$key} = $doc->get($url->fragment);
    }
  }
}

sub _track_ref {
  my ($self, $in, $key, $out) = @_;

  return 0 if !$in->{'$ref'};
  return 0 if ref $in->{'$ref'};

  my $url = Mojo::URL->new($in->{'$ref'});
  push @{$self->{refs}}, [$out, $key, $url];

  if ($url->scheme or $url->path->to_string) {
    my $doc = $self->_load($url);
    $self->_resolve_deep($doc, $url->fragment, $out);
  }

  return 1;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
