package Mojolicious::Command::swagger2;

=head1 NAME

Mojolicious::Command::swagger2 - mojo swagger2 command

=head1 DESCRIPTION

L<Mojolicious::Command::swagger2> is a command for interfacing with L<Swagger2>.

=head1 SYNOPSIS

  $ mojo swagger2 edit
  $ mojo swagger2 edit path/to/spec.json --listen http://*:5000
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
  # This command also takes whatever option "morbo" takes
  @{[__PACKAGE__->_usage('edit')]}

  # Write POD to STDOUT
  @{[__PACKAGE__->_usage('pod')]}

  # Run perldoc on the generated POD
  @{[__PACKAGE__->_usage('perldoc')]}

  # Validate an API file
  @{[__PACKAGE__->_usage('validate')]}

HERE

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

  $ENV{SWAGGER_API_FILE} = $file || '';
  $file ||= __FILE__;
  system 'morbo', -w => $file, @args, __FILE__;
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
  print Swagger2->new($file)->pod->to_string;
}

sub _action_validate {
  my ($self, $file) = @_;
  my @errors;

  die $self->_usage('validate'), "\n" unless $file;
  @errors = Swagger2->new($file)->validate;

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
  return "Usage: mojo swagger2 edit"                       if $_[0] eq 'edit';
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

  my $swagger = Swagger2->new;
  $app = Mojolicious->new;

  if ($ENV{SWAGGER_API_FILE}) {
    $app->defaults(raw => Mojo::Util::slurp($ENV{SWAGGER_API_FILE}));
    $swagger->load($ENV{SWAGGER_API_FILE});
  }

  $app->routes->get(
    '/' => sub {
      my $c = shift;
      $c->respond_to(
        txt => {data => $swagger->pod->to_string},
        any => sub {
          my $c = shift;
          $c->stash(layout => undef) if $c->req->is_xhr;
          $c->render(template => 'editor');
        }
      );
    }
  );
  $app->routes->post(
    '/' => sub {
      my $c = shift;
      eval {
        my $s = Swagger2->new->parse($c->req->body || '{}');
        $c->stash(layout => undef) if $c->req->is_xhr;
        $c->render(text => $c->pod_to_html($s->pod->to_string));
      } or do {
        my $e = $@;
        $c->app->log->error($e);
        $e =~ s!^(Could not.*?:)\s+!$1\n\n!s;
        $e =~ s!\s+at \S+\.pm line \d\S+!!g;
        $c->render(template => 'error', error => $e);
      };
    }
  );

  $app->defaults(swagger => $swagger, layout => 'default');
  $app->plugin('PODRenderer');
  unshift @{$app->renderer->classes}, __PACKAGE__;
  unshift @{$app->static->paths}, File::Spec->catdir(File::Basename::dirname(__FILE__), 'swagger2-public');
}

$app;

__DATA__
@@ error.html.ep
% title "Error in specification";
<h2>Error in specification</h2>
<pre><%= $error %></pre>

@@ editor.html.ep
% title "Editor";
<div id="editor"><%= stash('raw') || '---' %></div>
<div id="resizer">&nbsp;</div>
<div id="preview"><div class="pod-container"><%= pod_to_html $swagger->pod->to_string %></div></div>
%= javascript "ace.js"
%= javascript begin
(function(ace) {
  var localStorage = window.localStorage || {};
  var draggable = document.getElementById("resizer");
  var editor = document.getElementById("editor");
  var preview = document.getElementById("preview");
  var tid, xhr, i;

  var loaded = function() {
    var headings = preview.querySelectorAll("[id]");
    var id = location.href.split("#")[1];
    var scrollTo = id ? document.getElementById(id) : false;

    for (i = 0; i < headings.length; i++) {
      if (headings[i].tagName.toLowerCase().indexOf("h") != 0) continue;
      var a = document.createElement("a");
      a.href = "#" + headings[i].id;
      while (headings[i].firstChild) a.appendChild(headings[i].removeChild(headings[i].firstChild));
      headings[i].appendChild(a);
    }

    if (scrollTo) window.scroll(0, scrollTo.offsetTop);
    ace.session.setMode("ace/mode/" + (ace.getValue().match(/^\s*\{/) ? "json" : "yaml"));
  };

  var render = function() {
    xhr = new XMLHttpRequest();
    xhr.open("POST", "<%= url_for("/") %>", true);
    xhr.onload = function() { preview.firstChild.innerHTML = xhr.responseText; loaded(); };
    localStorage["swagger-spec"] = ace.getValue();
    xhr.send(localStorage["swagger-spec"]);
  };

  ace.setTheme("ace/theme/solarized_dark");
  ace.getSession().on("change", function(e) {
    if (tid) clearTimeout(tid);
    tid = setTimeout(render, 400);
  });

  if (localStorage["swagger-spec"]) {
    ace.setValue(localStorage["swagger-spec"]);
    render();
  }
  else {
    loaded();
  }

  var resize = function(width, done) {
    draggable.style.left = width + "px";
    editor.style.width = width + "px";
    preview.style.marginLeft = width + "px";
    if(done) ace.resize();
  };

  resize.x = false;
  resize.w = localStorage["swagger-editor-width"];

  if (resize.w) resize(resize.w, true);

  draggable.addEventListener("mousedown", function(e) { resize.x = e.clientX; resize.w = editor.offsetWidth; });
  window.addEventListener("resize", function(e) { if (resize.w > this.innerWidth) resize(this.innerWidth - 30, true); })
  window.addEventListener("mouseup", function(e) {
    if (resize.x === false) return;
    resize(resize.w + e.clientX - resize.x, true);
    resize.w = editor.offsetWidth;
    resize.x = false;
    localStorage["swagger-editor-width"] = resize.w;
  });
  window.addEventListener("mousemove", function(e) {
    if (resize.x === false) return;
    e.preventDefault();
    resize(resize.w + e.clientX - resize.x);
  });
})(ace.edit("editor"));
% end

@@ layouts/default.html.ep
<html>
<head>
  <title>Swagger2 - <%= title %></title>
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
  #editor, #resizer { position: fixed; top: 0; bottom: 0; }
  #editor {
    font-size: 14px;
    left: 0;
    width: 620px;
  }
  #resizer {
    border-left: 4px solid rgba(25, 63, 73, 0.99);
    left: 620px;
    width: 4px;
    cursor: ew-resize;
  }
  #preview { overflow: auto; margin-left: 620px; height: 100%; }
  #preview .pod-container { padding-left: 10px; padding-bottom: 100px; }
  #preview .link:hover { color: #679; cursor: pointer; }

  @media print {
    #editor, #resizer { display: none; }
    #preview { margin: 0; width: 100%; height: auto; }
    #preview .pod-container { padding: 0; }
  }
  % end
</head>
<body>
  %= content
</body>
</html>
