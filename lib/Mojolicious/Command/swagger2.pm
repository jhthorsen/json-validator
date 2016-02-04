package Mojolicious::Command::swagger2;
use Mojo::Base 'Mojolicious::Command';
use Mojo::Util;
use Swagger2;

my $app = __PACKAGE__;

# used in tests
our $OUT = \*STDOUT;

has description => 'Interface with Swagger2.';
has usage       => <<"HERE";
Usage:

  # Make a request to a Swagger server
  @{[__PACKAGE__->_usage('client')]}

  # Edit an API file in your browser
  # This command also takes whatever option "morbo" takes
  @{[__PACKAGE__->_usage('edit')]}

  # Write POD to STDOUT
  @{[__PACKAGE__->_usage('pod')]}

  # Run perldoc on the generated POD
  @{[__PACKAGE__->_usage('perldoc')]}

  # Validate an API file
  @{[__PACKAGE__->_usage('validate')]}

HERE

sub run {
  my $self   = shift;
  my $action = shift || 'unknown';
  my $code   = $self->can("_action_$action");

  die $self->usage unless $code;
  $self->$code(@_);
}

sub _action_client {
  my ($self, $file, @args) = @_;

  unshift @args, $file if $ENV{SWAGGER_API_FILE};
  $ENV{SWAGGER_COERCE_VALUES} //= 1;

  my $method   = shift @args;
  my $args     = {};
  my $base_url = $ENV{SWAGGER_BASE_URL};
  my $i        = 0;

  return print $OUT $self->_usage_client unless $ENV{SWAGGER_API_FILE} ||= $file;
  return print $OUT $self->_documentation_for('') if !$method or $method =~ /\W/;

  require Swagger2::Client;
  my $client = Swagger2::Client->generate($ENV{SWAGGER_API_FILE});

  for (@args) {
    return $self->_documentation_for($method) if $_ eq 'help';
    $base_url   = $args[$i + 1]                     if $_ eq '-b';
    $args       = Mojo::JSON::decode_json($args[0]) if /^\{/;
    $args->{$1} = $2                                if /^(\w+)=(.*)/;
    $i++;
  }

  $client->base_url->parse($base_url) if $base_url;
  eval {
    my $res = $client->$method($args);
    print $OUT $res->json ? Mojo::Util::dumper($res->json) : $res->body;
    1;
  } or do {
    my $e = $@;
    $e =~ s! at .* line.*!!s;
    warn "ERROR! $e\n";
  };
}

sub _action_edit {
  my ($self, $file, @args) = @_;

  unshift @args, $file if $ENV{SWAGGER_API_FILE};
  $ENV{SWAGGER_API_FILE} ||= $file || '';
  $ENV{SWAGGER_LOAD_EDITOR} = 1;
  $file ||= __FILE__;
  require Swagger2::Editor;
  system 'morbo', -w => $file, @args, $INC{'Swagger2/Editor.pm'};
}

sub _action_perldoc {
  my ($self, $file) = @_;

  die $self->_usage('perldoc'), "\n" unless $file;
  require Mojo::Asset::File;
  my $asset = Mojo::Asset::File->new;
  $asset->add_chunk(Swagger2->new($file)->pod->to_string);
  system perldoc => $asset->path;
}

sub _action_pod {
  my ($self, $file) = @_;

  die $self->_usage('pod'), "\n" unless $file;
  print $OUT Swagger2->new($file)->pod->to_string;
}

sub _action_validate {
  my ($self, $file) = @_;
  my @errors;

  die $self->_usage('validate'), "\n" unless $file;
  @errors = Swagger2->new($file)->validate;

  unless (@errors) {
    print $OUT "$file is valid.\n";
    return;
  }

  for my $e (@errors) {
    print $OUT "$e\n";
  }
}

sub _documentation_for {
  my ($self, $needle) = @_;
  my $pod = Swagger2->new($ENV{SWAGGER_API_FILE})->pod;
  my $paths = $pod->{api_spec}->get('/paths') || {};
  my @methods;

  for my $path (sort keys %$paths) {
    for my $method (sort keys %{$paths->{$path}}) {
      push @methods, $paths->{$path}{$method}{operationId} || join ' ', $method, $path;
      delete $paths->{$path}{$method} unless $methods[-1] eq $needle;
    }
    delete $paths->{$path} unless %{$paths->{$path}};
  }

  unless ($needle) {
    print $OUT "$_\n" for sort @methods;
    return;
  }

  require Pod::Simple;
  my $pod_text = Pod::Text->new;
  $pod_text->output_fh($OUT);
  $pod_text->parse_string_document($pod->_paths_to_string);
}

sub _usage {
  my $self = shift;
  return "Usage: mojo swagger2 edit"                                     if $_[0] eq 'edit';
  return "Usage: mojo swagger2 perldoc path/to/spec.json"                if $_[0] eq 'perldoc';
  return "Usage: mojo swagger2 pod path/to/spec.json"                    if $_[0] eq 'pod';
  return "Usage: mojo swagger2 validate path/to/spec.json"               if $_[0] eq 'validate';
  return "Usage: mojo swagger2 client path/to/spec.json <method> [args]" if $_[0] eq 'client';
  die "No usage for '@_'";
}

sub _usage_client {
  my $self = shift;

  return <<HERE;
Usage:
  # Call a method with arguments
  mojo swagger2 client path/to/spec.json <method> [args]

  # List methods
  mojo swagger2 client path/to/spec.json

  # Get documentation for a method
  mojo swagger2 client path/to/spec.json <method> help

  # Specify spec and/or base URL from environment.
  # Useful for shell wrappers
  SWAGGER_API_FILE=path/to/spec.json mojo swagger2 client <method>
  SWAGGER_BASE_URL=https://example.com/1.0 mojo swagger2 client <method>

  # Example arguments
  mojo swagger2 client path/to/spec.json list_pets '{"limit":10}'
  mojo swagger2 client path/to/spec.json list_pets limit=10 owner=joe
  mojo swagger2 client path/to/spec.json -b https://example.com/1.0 list_pets limit=10 owner=joe
HERE
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Command::swagger2 - mojo swagger2 command

=head1 DESCRIPTION

L<Mojolicious::Command::swagger2> is a command for interfacing with L<Swagger2>.

=head1 SYNOPSIS

  # Call a method with arguments
  mojo swagger2 client path/to/spec.json <method> [args]

  # List methods
  mojo swagger2 client path/to/spec.json

  # Get documentation for a method
  mojo swagger2 client path/to/spec.json <method> help

  # Specify spec and/or base URL from environment.
  # Useful for shell wrappers
  SWAGGER_API_FILE=path/to/spec.json mojo swagger2 client <method>
  SWAGGER_BASE_URL=https://example.com/1.0 mojo swagger2 client <method>

  # Example arguments
  mojo swagger2 client path/to/spec.json list_pets '{"limit":10}'
  mojo swagger2 client path/to/spec.json list_pets limit=10 owner=joe
  mojo swagger2 client path/to/spec.json -b https://example.com/1.0 list_pets limit=10 owner=joe

=head1 ATTRIBUTES

=head2 description

Returns description of this command.

=head2 usage

Returns usage of this command.

=head1 METHODS

=head2 run

See L</SYNOPSIS>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014-2015, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
