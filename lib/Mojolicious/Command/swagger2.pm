package Mojolicious::Command::swagger2;

=head1 NAME

Mojolicious::Command::swagger2 - mojo swagger2 command

=head1 DESCRIPTION

L<Mojolicious::Command::swagger2> is a command for interfacing with L<Swagger2>.

=head1 SYNOPSIS

  $ mojo swagger2 edit path/to/spec.json
  $ mojo swagger2 pod path/to/spec.json
  $ mojo swagger2 perldoc path/to/spec.json
  $ mojo swagger2 validate path/to/spec.json

=cut

use Mojo::Base 'Mojolicious::Command';
use Swagger2;

my $app = __PACKAGE__;

=head1 ATTRIBUTES

=head2 description

Returns description of this command.

=head2 usage

Returns usage of this command.

=cut

has description => 'Interface with Swagger2.';
has usage       => <<"HERE";
Usage:

  # Edit an API file in your browser
  @{[__PACKAGE__->_usage('edit')]}

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

sub _action_edit {
  my ($self, $file, @args) = @_;

  die $self->_usage('edit'), "\n" unless $file;
  die "Cannot read $file\n" unless -r $file;
  $ENV{SWAGGER_API_FILE} = $file;
  system morbo => -w => $file, @args, __FILE__;
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
  my $self = shift;
  return "Usage: mojo swagger2 edit path/to/spec.json"     if $_[0] eq 'edit';
  return "Usage: mojo swagger2 perldoc path/to/spec.json"  if $_[0] eq 'perldoc';
  return "Usage: mojo swagger2 pod path/to/spec.json"      if $_[0] eq 'pod';
  return "Usage: mojo swagger2 validate path/to/spec.json" if $_[0] eq 'validate';
  die "No usage for '@_'";
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

if ($ENV{MOJO_APP_LOADER}) {
  require File::Basename;
  require Mojolicious;
  require Mojolicious::Plugin::PODRenderer;

  my $swagger     = Swagger2->new($ENV{SWAGGER_API_FILE});
  my $module      = File::Basename::basename($swagger->url->path);
  my $pod_to_html = Mojolicious::Plugin::PODRenderer->can('_html');
  my $pod         = $swagger->pod->to_string;

  $app = Mojolicious->new;
  $module =~ s!\.\w+$!!;

  $app->routes->get(
    "/" => sub {
      my $c = shift;
      $c->render(template => 'editor', pod => $c->pod_to_html($pod));
    }
  );
  $app->routes->get(
    "/perldoc/$module",
    sub {
      my $c = shift;
      $c->stash(layout => undef) if $c->req->is_xhr;
      $c->respond_to(txt => {data => $pod}, any => sub { $_[0]->render(text => $_[0]->pod_to_html($pod), pod => 1) });
    }
  );
  $app->routes->post(
    "/perldoc/$module" => sub {
      my $c       = shift;
      my $swagger = Swagger2->new->parse($c->req->body);
      $c->render(text => $c->pod_to_html($swagger->pod->to_string));
    }
  );

  $app->defaults(module => $module, layout => 'default');
  $app->plugin('PODRenderer');
  unshift @{$app->renderer->classes}, __PACKAGE__;
  unshift @{$app->static->paths}, File::Spec->catdir(File::Basename::dirname(__FILE__), 'swagger2-public');
}

$app;

__DATA__
@@ editor.html.ep
<div id="editor" class="editor"><%= Mojo::Util::slurp($ENV{SWAGGER_API_FILE}) %></div>
<div id="preview"><div class="pod-container"><%= $pod %></div></div>
%= javascript 'ace.js'
%= javascript begin
(function(editor) {
  var localStorage = window.localStorage || {};
  var preview = document.getElementById("preview");
  var tid, xhr, i;

  var loaded = function() {
    var headings = preview.querySelectorAll("[id]");
    var id = location.href.split("#")[1];
    var scrollTo = id ? document.getElementById(id) : false;

    for (i = 0; i < headings.length; i++) {
      if (headings[i].tagName.toLowerCase().indexOf('h') != 0) continue;
      var a = document.createElement("a");
      a.href = "#" + headings[i].id;
      while (headings[i].firstChild) a.appendChild(headings[i].removeChild(headings[i].firstChild));
      headings[i].appendChild(a);
    }

    if (scrollTo) window.scroll(0, scrollTo.offsetTop);
  };

  var render = function() {
    xhr = new XMLHttpRequest();
    xhr.open("POST", "<%= url_for("/perldoc/$module") %>", true);
    xhr.onload = function() { preview.firstChild.innerHTML = xhr.responseText; loaded(); };
    localStorage["editor"] = editor.getValue();
    xhr.send(localStorage["editor"]);
  };

  if (localStorage["editor"]) {
    editor.setValue(localStorage["editor"]);
    render();
  }

  editor.setTheme("ace/theme/solarized_dark");
  editor.getSession().setMode("ace/mode/json");
  editor.getSession().on("change", function(e) {
    if (tid) clearTimeout(tid);
    tid = setTimeout(render, 400);
  });

  loaded();
})(ace.edit("editor"));
% end

@@ layouts/default.html.ep
<html>
<head>
  <title>Edit <%= $module %></title>
  %= stylesheet begin
  html, body {
    background: #eee;
    font-family: sans-serif;
    font-size: 14px;
    color: #111;
    margin: 0;
    padding: 0;
    height: 100%;
    width: 100%;
  }
  a { color: #222; }
  h1 a, h2 a, h3 a { text-decoration: none; }
  h1 a:hover, h2 a:hover, h3 a:hover { text-decoration: underline; }
  #editor {
    font-size: 14px;
    top: 0;
    left: 0;
    bottom: 0;
    width: 620px;
    position: fixed;
  }
  #preview { overflow: auto; margin-left: 620px; height: 100%; }
  #preview .pod-container { padding-left: 10px; padding-bottom: 100px; }
  #preview .link:hover { color: #679; cursor: pointer; }
  % end
</head>
<body>
  %= content
</body>
</html>
