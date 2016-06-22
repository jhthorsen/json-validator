package Swagger2;
use Mojo::Base -base;
use Mojo::Asset::File;
use Mojo::JSON;
use Mojo::JSON::Pointer;
use Mojo::URL;
use File::Basename ();
use File::Spec;
use JSON::Validator::OpenAPI;

our $VERSION = '0.82';

# Should be considered internal
our $JS_CLIENT
  = File::Spec->catfile(File::Basename::dirname(__FILE__), 'Swagger2', 'swagger2-client.js');

has api_spec => sub {
  my $self = shift;
  return $self->_validator->_load_schema($self->url) if '' . $self->url;
  return Mojo::JSON::Pointer->new({});
};

has base_url => sub {
  my $self = shift;
  my $url  = Mojo::URL->new;
  my ($schemes, $v);

  $self->load if !$self->{api_spec} and '' . $self->url;
  $schemes = $self->api_spec->get('/schemes') || [];
  $url->host($self->api_spec->get('/host')     || 'example.com');
  $url->path($self->api_spec->get('/basePath') || '/');
  $url->scheme($schemes->[0]                   || 'http');

  return $url;
};

has _specification => sub { shift->_validator->schema('http://swagger.io/v2/schema.json')->schema };

has _validator => sub { JSON::Validator::OpenAPI->new };

sub ua  { shift->_validator->ua(@_) }
sub url { shift->{url} }

sub expand {
  my $self   = shift;
  my $class  = Scalar::Util::blessed($self);
  my $schema = $self->_validator->schema($self->api_spec->data)->schema;
  $class->new(%$self)->api_spec($schema);
}

sub find_operations {
  my ($self, $needle) = @_;
  my $paths      = $self->api_spec->get('/paths');
  my $operations = [];

  $needle ||= {};
  $needle = {operationId => $needle} unless ref $needle;

  for my $path (keys %$paths) {
    next if $path =~ /^x-/;
    next if $needle->{path} and $needle->{path} ne $path;
    for my $method (keys %{$paths->{$path}}) {
      my $object = $paths->{$path}{$method};
      next if $method =~ /^x-/;
      next if $needle->{tag} and !grep { $needle->{tag} eq $_ } @{$object->{tags} || []};
      next if $needle->{method} and $needle->{method} ne $method;
      next if $needle->{operationId} and $needle->{operationId} ne $object->{operationId};
      push @$operations, $object;
    }
  }

  return $operations;
}

sub javascript_client { Mojo::Asset::File->new(path => $JS_CLIENT) }

sub load {
  my $self = shift;
  delete $self->{base_url};
  $self->{url} = Mojo::URL->new(shift) if @_;
  $self->{api_spec} = $self->api_spec;
  $self;
}

sub new {
  my $class = shift;
  my $url   = @_ % 2 ? shift : '';
  my $self  = $class->SUPER::new(@_);

  $url =~ s!^file://!!;
  $self->{url} ||= $url;
  $self->{url} = Mojo::URL->new($self->{url}) unless ref $self->{url};
  $self;
}

sub parse {
  my ($self, $doc, $namespace) = @_;
  delete $self->{base_url};
  $namespace ||= 'http://127.0.0.1/#';
  $self->{url}      = Mojo::URL->new($namespace);
  $self->{api_spec} = Mojo::JSON::Pointer->new($self->_validator->_load_schema_from_text($doc));
  $self;
}

sub pod {
  my $self     = shift;
  my $resolved = $self->_validator->schema($self->api_spec->data)->schema;
  require Swagger2::POD;
  Swagger2::POD->new(base_url => $self->base_url, api_spec => $resolved);
}

sub to_string {
  my $self = shift;
  my $format = shift || 'json';

  return DumpYAML($self->api_spec->data) if $format eq 'yaml';
  return Mojo::JSON::encode_json($self->api_spec->data);
}

sub validate {
  my $self = shift;
  $self->_validator->validate($self->expand->api_spec->data, $self->_specification->data);
}

sub _is_true {
  return $_[0] if ref $_[0] and !Scalar::Util::blessed($_[0]);
  return 0 if !$_[0] or $_[0] =~ /^(n|false|off)/i;
  return 1;
}

1;

=encoding utf8

=head1 NAME

Swagger2 - Swagger RESTful API Documentation

=head1 VERSION

0.82

=head1 DESCRIPTION

L<Swagger2> is a module for generating, parsing and transforming
L<swagger|http://swagger.io/> API specification. It has support for reading
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
  print $swagger->api_spec->get("/swagger");

  # Returns the specification as a POD document
  print $swagger->pod->to_string;

=head1 ATTRIBUTES

=head2 api_spec

  $pointer = $self->api_spec;
  $self = $self->api_spec(Mojo::JSON::Pointer->new({}));

Holds a L<Mojo::JSON::Pointer> object containing your API specification.

=head2 base_url

  $mojo_url = $self->base_url;

L<Mojo::URL> object that holds the location to the API endpoint.
Note: This might also just be a dummy URL to L<http://example.com/>.

=head2 ua

  $ua = $self->ua;
  $self = $self->ua(Mojo::UserAgent->new);

A L<Mojo::UserAgent> used to fetch remote documentation.

=head2 url

  $mojo_url = $self->url;

L<Mojo::URL> object that holds the location to the documentation file.
This can be both a location on disk or an URL to a server. A remote
resource will be fetched using L<Mojo::UserAgent>.

=head1 METHODS

=head2 expand

  $swagger = $self->expand;

This method returns a new C<Swagger2> object, where all the
L<references|https://tools.ietf.org/html/draft-zyp-json-schema-03#section-5.28>
are resolved.

=head2 find_operations

  $operations = $self->find_operations(\%q);

Used to find a list of L<Operation Objects|http://swagger.io/specification/#operationObject>
from the specification. C<%q> can be:

  $all        = $self->find_operations;
  $operations = $self->find_operations($operationId);
  $operations = $self->find_operations({operationId => "listPets"});
  $operations = $self->find_operations({method => "post", path => "/pets"});
  $operations = $self->find_operations({tag => "pets"});

=head2 javascript_client

  $file = $self->javascript_client;

Returns a L<Mojo::Asset::File> object which points to a file containing a
custom JavaScript file which can communicate with
L<Mojolicious::Plugin::Swagger2>.

See L<https://github.com/jhthorsen/swagger2/blob/master/lib/Swagger2/swagger2-client.js>
for source code.

C<swagger2-client.js> is currently EXPERIMENTAL!

=head2 load

  $self = $self->load;
  $self = $self->load($url);

Used to load the content from C<$url> or L</url>. This method will try to
guess the content type (JSON or YAML) by looking at the content of the C<$url>.

=head2 new

  $self = Swagger2->new($url);
  $self = Swagger2->new(%attributes);
  $self = Swagger2->new(\%attributes);

Object constructor.

=head2 parse

  $self = $self->parse($text);

Used to parse C<$text> instead of L<loading|/load> data from L</url>.

The type of input text can be either JSON or YAML. It will default to YAML,
but parse the text as JSON if it starts with "{".

=head2 pod

  $pod_object = $self->pod;

Returns a L<Swagger2::POD> object.

=head2 to_string

  $json = $self->to_string;
  $json = $self->to_string("json");
  $yaml = $self->to_string("yaml");

This method can transform this object into Swagger spec.

=head2 validate

  @errors = $self->validate;

Will validate L</api_spec> against
L<Swagger RESTful API Documentation Specification|https://github.com/swagger-api/swagger-spec/blob/master/versions/2.0.md>,
and return a list with all the errors found. See also L<JSON::Validator/validate>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014-2015, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
