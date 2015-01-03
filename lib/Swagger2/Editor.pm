package Swagger2::Editor;

=head1 NAME

Swagger2::Editor - A WEB based Swagger2 API editor

=head1 DESCRIPTION

L<Swagger2::Editor> is a WEB based Swagger2 API editor.

=head1 SYNOPSIS

  $ mojo swagger2 edit /path/to/api.json --listen http://*:3000

=cut

use Mojo::Base 'Mojolicious';
use Mojo::Util;
use File::Basename;
use Swagger2;

=head1 ROUTES

=head2 GET /

=cut

sub _get {
  my $c = shift;

  $c->respond_to(
    txt => {data => $c->app->_swagger->pod->to_string},
    any => sub {
      my $c = shift;
      $c->stash(layout => undef) if $c->req->is_xhr;
      $c->render(template => 'editor');
    }
  );
}

sub _post {
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

has _swagger => sub { Swagger2->new };

=head1 METHODS

=head2 startup

Used to set up the L</ROUTES>.

=cut

sub startup {
  my $self = shift;

  if ($ENV{SWAGGER_API_FILE}) {
    my $api_url = Mojo::URL->new;
    $api_url->path->parts([File::Spec->splitdir($ENV{SWAGGER_API_FILE})]);
    $self->_swagger->load($api_url);
    $self->defaults(raw => Mojo::Util::slurp($ENV{SWAGGER_API_FILE}));
  }

  unshift @{$self->renderer->classes}, __PACKAGE__;
  unshift @{$self->static->paths}, File::Spec->catdir(File::Basename::dirname(__FILE__), 'public');

  $self->routes->get('/' => \&_get);
  $self->routes->post('/' => \&_post);
  $self->defaults(swagger => $self->_swagger, layout => 'default');
  $self->plugin('PODRenderer');
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

$ENV{MOJO_APP_LOADER} ? __PACKAGE__->new : 1;

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
