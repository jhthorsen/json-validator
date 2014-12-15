package Mojolicious::Command::swagger2;

=head1 NAME

Mojolicious::Command::swagger2 - mojo swagger2 command

=head1 DESCRIPTION

L<Mojolicious::Command::swagger2> is a command for interfacing with L<Swagger2>.

=head1 SYNOPSIS

  $ mojo swagger2 pod path/to/spec.json
  $ mojo swagger2 perldoc path/to/spec.json
  $ mojo swagger2 validate path/to/spec.json

=cut

use Mojo::Base 'Mojolicious::Command';
use Swagger2;

=head1 ATTRIBUTES

=head2 description

Returns description of this command.

=head2 usage

Returns usage of this command.

=cut

has description => 'Interface with Swagger2.';
has usage       => <<"HERE";
Usage:

  # Write POD to STDOUT
  @{[__PACKAGE__->_usage('pod')]}

  # Run perldoc on the generated POD
  @{[__PACKAGE__->_usage('perldoc')]}

  # Validate an API file
  @{[__PACKAGE__->_usage('validate')]}

HERE

has _swagger2 => sub { Swagger2->new };

=head1 METHODS

=head2 run

See L</SYNOPSIS>.

=cut

sub run {
  my $self   = shift;
  my $action = shift || 'unknown';
  my $code   = $self->can("_action_$action");

  die $self->usage unless $code;
  $self->$code(@_);
}

sub _action_perldoc {
  my ($self, $file) = @_;

  die $self->_usage('perldoc'), "\n" unless $file;
  require Mojo::Asset::File;
  my $asset = Mojo::Asset::File->new;
  $asset->add_chunk($self->_swagger2->load($file)->pod->to_string);
  system perldoc => $asset->path;
}

sub _action_pod {
  my ($self, $file) = @_;

  die $self->_usage('pod'), "\n" unless $file;
  print $self->_swagger2->load($file)->pod->to_string;
}

sub _action_validate {
  my ($self, $file) = @_;
  my @errors;

  die $self->_usage('validate'), "\n" unless $file;
  @errors = $self->_swagger2->load($file)->validate;

  unless (@errors) {
    print "$file is valid.\n";
    return;
  }

  for my $e (@errors) {
    print "$e\n";
  }
}

sub _usage {
  return "Usage: mojo swagger2 perldoc path/to/spec.json"  if $_[1] eq 'perldoc';
  return "Usage: mojo swagger2 pod path/to/spec.json"      if $_[1] eq 'pod';
  return "Usage: mojo swagger2 validate path/to/spec.json" if $_[1] eq 'validate';
  return "";
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
