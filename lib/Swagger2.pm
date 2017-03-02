package Swagger2;
use Mojo::Base -base;
use Mojo::Asset::File;
use Mojo::JSON;
use Mojo::JSON::Pointer;
use Mojo::URL;
use File::Basename ();
use File::Spec;
use Mojo::Util 'deprecated';
use JSON::Validator::OpenAPI;

our $VERSION = '0.89';

# Should be considered internal
our $JS_CLIENT
  = File::Spec->catfile(File::Basename::dirname(__FILE__), 'Swagger2', 'swagger2-client.js');

deprecated "https://metacpan.org/pod/Swagger2#DEPRECATION-WARNING";

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

Swagger2 - Deprecated

=head1 VERSION

0.89

=head1 DEPRECATION WARNING

The L<Swagger2> distribution is no longer actively maintained. Only severe bug
fixes and pull requests will move this code forward.  The reason behind this is
that the code is too complex and hard to maintain.

So what should you use instead?

=over 2

=item * L<Swagger2>

L<Swagger2> is either not very useful or replaced by L<JSON::Validator>.

=item * L<Swagger2::Client>

No alternatives. The issue with this module is that it does not understand if
you have parameters with the same name. There might be a L<OpenAPI::Client> at
some point, but it is currently no plans to write it.

=item * L<Swagger2::Editor>

No alternatives.

=item * L<Swagger2::POD>

L<Swagger2::POD> is not very good and also very hard to maintain.
L<Mojolicious::Plugin::OpenAPI> has a HTML renderer which makes documentation
that is much easier to read and always in sync with the application.

When that is said: The renderer in L<Mojolicious::Plugin::OpenAPI> need
refinement.

=item * L<Swagger2::SchemaValidator>

L<Mojolicious::Plugin::OpenAPI> has the validator built in. For other purposes,
use L<JSON::Validator> or L<JSON::Validator::OpenAPI> instead.

=item * L<Mojolicious::Command::swagger2>

No alternatives.

=item * L<Mojolicious::Plugin::Swagger2>

Use L<Mojolicious::Plugin::OpenAPI> instead. L<Mojolicious::Plugin::OpenAPI>
plays much nicer together with the L<Mojolicious> framework.

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014-2015, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
