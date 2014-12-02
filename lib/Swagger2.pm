package Swagger2;

=head1 NAME

Swagger2 - Swagger RESTful API Documentation

=head1 VERSION

0.01

=head1 DESCRIPTION

L<Swagger2> is a module for generating, parsing and transforming
L<swagger|http://swagger.io/> API documentation.

=head1 DEPENDENCIES

=over 4

=item * YAML parser

A L<YAML> parser is required if you want to read/write spec written in
the YAML format. Supported modules are L<YAML::XS>, L<YAML::Syck>, L<YAML>
and L<YAML::Tiny>.

=back

=head1 SYNOPSIS

  use Swagger2;
  my $swagger = Sswagger2->new("file:///path/to/api-spec.yaml");

  print $swagger->tree->get("/swagger"); # Should return 2.0

=cut

use Mojo::Base -base;
use Mojo::JSON;
use Mojo::JSON::Pointer;
use Mojo::URL;
use Mojo::Util ();

our $VERSION = '0.01';

my @YAML_MODULES = qw( YAML::Tiny YAML YAML::Syck YAML::XS );
my $YAML_MODULE = $ENV{SWAGGER_YAML_MODULE} || (grep { eval "require $_;1" } @YAML_MODULES)[0];

Mojo::Util::monkey_patch(__PACKAGE__, LoadYAML => eval "\&$YAML_MODULE\::Load" || sub {die "Need to install a YAML module: @YAML_MODULES"});
Mojo::Util::monkey_patch(__PACKAGE__, DumpYAML => eval "\&$YAML_MODULE\::Dump" || sub {die "Need to install a YAML module: @YAML_MODULES"});

=head1 ATTRIBUTES

=head2 tree

  $pointer = $self->tree;
  $self = $self->tree(Mojo::JSON::Pointer->new({}));

Holds a L<Mojo::JSON::Pointer> object. This attribute will be built from
L</load>, if L</url> is set.

=head2 ua

  $ua = $self->ua;
  $self = $self->ua(Mojo::UserAgent->new);

A L<Mojo::UserAgent> used to fetch remote documentation.

=head2 url

  $str = $self->url;

URL to documentation file.

=cut

has tree => sub {
  my $self = shift;

  $self->load if $self->url;
  $self->{tree} || Mojo::JSON::Pointer->new({});
};

has ua => sub {
  require Mojo::UserAgent;
  Mojo::UserAgent->new;
};

sub url { shift->{url} }

=head1 METHODS

=head2 load

  $self = $self->load;

Used to load the content from C</url>.

=cut

sub load {
  my $self = shift;
  my $scheme = $self->{url}->scheme || 'file';
  my $tree = {};
  my $data;

  $self->{url} = Mojo::URL->new(shift) if @_;

  if ($scheme eq 'file') {
    $data = Mojo::Util::slurp($self->{url}->path);
  }
  else {
    $data = $self->ua->get($self->{url})->res->body;
  }

  if ($self->{url}->path =~ /\.yaml/) {
    $tree = LoadYAML($data);
  }
  elsif ($self->{url}->path =~ /\.json/) {
    $tree = Mojo::JSON::decode_json($data);
  }

  $self->{tree} = Mojo::JSON::Pointer->new($tree);
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
  my $url = @_ % 2 ? shift : '';
  my $self = $class->SUPER::new(url => $url, @_);

  $self->{url} = Mojo::URL->new($self->{url});
  $self;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
