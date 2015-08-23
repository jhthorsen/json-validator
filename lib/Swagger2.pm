package Swagger2;

=head1 NAME

Swagger2 - Swagger RESTful API Documentation

=head1 VERSION

0.49

=head1 DESCRIPTION

L<Swagger2> is a module for generating, parsing and transforming
L<swagger|http://swagger.io/> API documentation. It has support for reading
swagger specification in JSON notation and as well YAML format.

Please read L<http://thorsen.pm/perl/programming/2015/07/05/mojolicious-swagger2.html>
for an introduction to Swagger and reasons for why you would to use it.

=head2 Mojolicious server side code generator

This distribution comes with a L<Mojolicious> plugin,
L<Mojolicious::Plugin::Swagger2>, which can set up routes and perform input
and output validation.

=head2 Mojolicious client side code generator

Swagger2 also comes with a L<Swagger2::Client> generator, which converts the client
spec to perl code in memory.

=head1 RECOMMENDED MODULES

=over 4

=item * YAML parser

A L<YAML> parser is required if you want to read/write spec written in
the YAML format. Supported modules are L<YAML::XS>, L<YAML::Syck>, L<YAML>
and L<YAML::Tiny>.

=back

=head1 SYNOPSIS

  use Swagger2;
  my $swagger = Swagger2->new("/path/to/api-spec.yaml");

  # Access the raw specification values
  print $swagger->tree->get("/swagger");

  # Returns the specification as a POD document
  print $swagger->pod->to_string;

=cut

use Mojo::Base -base;
use Mojo::JSON;
use Mojo::JSON::Pointer;
use Mojo::URL;
use File::Basename ();
use File::Spec;

our $VERSION = '0.49';

# Should be considered internal
our $SPEC_FILE = File::Spec->catfile(File::Basename::dirname(__FILE__), 'Swagger2', 'schema.json');

=head1 ATTRIBUTES

=head2 base_url

  $mojo_url = $self->base_url;

L<Mojo::URL> object that holds the location to the API endpoint.
Note: This might also just be a dummy URL to L<http://example.com/>.

=head2 specification

DEPRECATED.

If you need to change this, then you probably want L<JSON::Validator> instead.

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

has specification => sub { shift->_validator->schema($SPEC_FILE)->schema; };

has tree => sub {
  my $self = shift;
  return $self->_validator->_load_schema($self->url) if '' . $self->url;
  return Mojo::JSON::Pointer->new({});
};

has _validator => sub {
  require Swagger2::SchemaValidator;
  Swagger2::SchemaValidator->new->cache_dir($ENV{SWAGGER2_CACHE_DIR}
      || File::Spec->catdir(File::Basename::dirname(__FILE__), qw( Swagger2 public cache )));
};

sub ua  { shift->_validator->ua(@_) }
sub url { shift->{url} }

=head1 METHODS

=head2 expand

  $swagger = $self->expand;

This method returns a new C<Swagger2> object, where all the
L<references|https://tools.ietf.org/html/draft-zyp-json-schema-03#section-5.28>
are resolved.

=cut

sub expand {
  my $self  = shift;
  my $class = Scalar::Util::blessed($self);
  $class->new(%$self)->tree($self->_validator->schema($self->tree->data)->schema);
}

=head2 load

  $self = $self->load;
  $self = $self->load($url);

Used to load the content from C<$url> or L</url>. This method will try to
guess the content type (JSON or YAML) by looking at the content of the C<$url>.

=cut

sub load {
  my $self = shift;
  delete $self->{base_url};
  $self->{url} = Mojo::URL->new(shift) if @_;
  $self->{tree} = $self->_validator->_load_schema($self->{url});
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
  my $self  = $class->SUPER::new(@_);

  $url =~ s!^file://!!;
  $self->{url} = Mojo::URL->new($url);
  $self;
}

=head2 parse

  $self = $self->parse($text);

Used to parse C<$text> instead of L<loading|/load> data from L</url>.

The type of input text can be either JSON or YAML. It will default to YAML,
but parse the text as JSON if it starts with "{".

=cut

sub parse {
  my ($self, $doc, $namespace) = @_;
  delete $self->{base_url};
  $namespace ||= 'http://127.0.0.1/#';
  $self->{url}  = Mojo::URL->new($namespace);
  $self->{tree} = Mojo::JSON::Pointer->new($self->_validator->_load_schema_from_text($doc));
  $self;
}

=head2 pod

  $pod_object = $self->pod;

Returns a L<Swagger2::POD> object.

=cut

sub pod {
  my $self     = shift;
  my $resolved = $self->_validator->schema($self->tree->data)->schema;
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
    return Mojo::JSON::encode_json($self->tree->data);
  }
}

=head2 validate

  @errors = $self->validate;

Will validate L</tree> against L</specification>, and return a list with all
the errors found. See also L<Swagger2::SchemaValidator/validate>.

=cut

sub validate {
  my $self = shift;
  $self->_validator->validate($self->tree->data, $self->specification->data);
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014-2015, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
