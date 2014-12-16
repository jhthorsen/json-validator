package Swagger2;

=head1 NAME

Swagger2 - Swagger RESTful API Documentation

=head1 VERSION

0.12

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
use File::Basename ();
use File::Spec;
use constant CACHE_DIR => $ENV{SWAGGER2_CACHE_DIR} || '';
use constant DEBUG     => $ENV{SWAGGER2_DEBUG}     || 0;

our $VERSION = '0.12';

# Should be considered internal
our $SPEC_FILE = do {
  join '/', File::Spec->splitdir(File::Basename::dirname(__FILE__)), 'Swagger2', 'schema.json';
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
  my $expanded = $self->_expand($self->tree);

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

=head2 parse

  $self = $self->parse($text);

Used to parse C<$text> instead of L<loading|/load> data from L</url>.

The type of input text can be either JSON or YAML. It will default to YAML,
but parse the text as JSON if it starts with "{".

=cut

sub parse {
  my ($self, $doc) = @_;
  my $type = $doc =~ /^\s*\{/s ? 'json' : 'yaml';
  my $namespace = 'http://127.0.0.1/#';

  $self->{url} = Mojo::URL->new($namespace);
  $self->_parse($doc, $type, $namespace);
  $self;
}

=head2 pod

  $pod_object = $self->pod;

Returns a L<Swagger2::POD> object.

=cut

sub pod {
  my $self     = shift;
  my $resolved = $self->_expand($self->tree);

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
  my $schema = $self->_expand($self->specification);

  return $self->_validator->validate($self->_expand($self->tree)->data, $schema->data);
}

sub _clone {
  my ($self, $obj, $namespace, $refs) = @_;
  my $copy = ref $obj eq 'ARRAY' ? [] : {};
  my $ref;

  if (ref $obj eq 'HASH') {
    $obj = $ref if $ref = $self->_find_ref($obj->{'$ref'}, $namespace, $refs);
    $copy->{$_} = $self->_clone($obj->{$_}, $namespace, $refs) for keys %$obj;
    delete $copy->{'$ref'};
    return $copy;
  }
  elsif (ref $obj eq 'ARRAY') {
    $copy->[$_] = $self->_clone($obj->[$_], $namespace, $refs) for 0 .. @$obj - 1;
    return $copy;
  }

  return $obj;
}

sub _find_ref {
  my ($self, $ref, $namespace, $refs) = @_;
  my ($doc, $def);

  if (!$ref or ref $ref) {
    return;
  }
  if ($ref =~ /^\w+$/) {
    $ref = "#/definitions/$ref";
  }
  if ($ref =~ s!^\#!!) {
    $ref = Mojo::URL->new($namespace)->fragment($ref);
  }
  else {
    $ref = Mojo::URL->new($ref);
  }

  return $refs->{$ref} if $refs->{$ref};
  warn "[Swagger2] Resolve $ref\n" if DEBUG;
  $refs->{$ref} = {};
  $doc = $self->_load($ref);
  $def = $self->_clone($doc->get($ref->fragment), $doc->data->{id}, $refs);
  $refs->{$ref}{$_} = $def->{$_} for keys %$def;
  $refs->{$ref};
}

sub _expand {
  my ($self, $pointer) = @_;

  Mojo::JSON::Pointer->new($self->_clone($pointer->data, $pointer->data->{id}, {}));
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

    $type ||= $doc =~ /^\s*{/s ? 'json' : 'yaml';
  }

  return $self->_parse($doc, $type, $namespace);
}

sub _parse {
  my ($self, $doc, $type, $namespace) = @_;

  warn "[Swagger2] Register $namespace ($type)\n" if DEBUG;

  # parse the document
  eval { $doc = $type eq 'yaml' ? LoadYAML($doc) : decode_json($doc); } or do {
    die "Could not load document from $namespace: $@ ($doc)";
  };

  $doc = Mojo::JSON::Pointer->new($doc);
  $self->{loaded}{$namespace} = $doc;
  $doc->data->{id} ||= "$namespace";
  $self->{loaded}{$doc->data->{id}} = $doc;
  $doc;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
