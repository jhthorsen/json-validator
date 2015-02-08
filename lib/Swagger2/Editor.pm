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

=head1 ATTRIBUTES

=head2 specification_file

Returns path to swagger specification file. Defaults to
C<SWAGGER_API_FILE> environment variable.

=cut

has specification_file => sub { $ENV{SWAGGER_API_FILE} || '' };

has _swagger => sub { Swagger2->new };

=head1 ROUTES

=head2 GET /

Will render the editor and any Swagger specification given as input.

Can also just render the POD if requested as C</.txt> instead.

=cut

sub _get {
  my $c = shift;

  $c->respond_to(
    txt => {data => $c->app->_swagger->pod->to_string, layout => undef},
    any => sub {
      my $c = shift;
      $c->stash(layout => undef) if $c->req->is_xhr;
      $c->render(template => 'editor');
    }
  );
}

=head2 POST /

Will L<parse|Swagger/parse> the JSON/YAML in the HTTP body and render it as POD.

=cut

sub _post {
  my $c = shift;

  eval {
    my $s = Swagger2->new->parse($c->req->body || '{}');
    $c->render(text => $c->podify($s->pod), layout => undef);
  } or do {
    my $e = $@;
    $c->app->log->error($e);
    $e =~ s!^(Could not.*?:)\s+!$1\n\n!s;
    $e =~ s!\s+at \S+\.pm line \d\S+!!g;
    $c->render(template => 'error', error => $e);
  };
}

=head1 METHODS

=head2 startup

Used to set up the L</ROUTES>.

=cut

sub startup {
  my $self = shift;

  if (my $file = $self->specification_file) {
    my $api_url = Mojo::URL->new;
    $api_url->path->parts([File::Spec->splitdir($file)]);
    $self->_swagger->load($api_url);
    $self->defaults(raw => Mojo::Util::slurp($file));
  }

  unshift @{$self->renderer->classes}, __PACKAGE__;
  unshift @{$self->static->paths}, File::Spec->catdir(File::Basename::dirname(__FILE__), 'public');

  $self->routes->get('/' => \&_get);
  $self->routes->post('/' => \&_post);
  $self->defaults(swagger => $self->_swagger, layout => 'default');
  $self->plugin('PODRenderer');
  $self->helper(podify => \&_podify);
}

sub _podify {
  my ($c, $pod) = @_;
  my $dom = Mojo::DOM->new($c->pod_to_html($pod->to_string));
  my $ul  = '<ul>';
  my ($sub, @parts);

  for my $e ($dom->find('h1, h2')->each) {
    my $id     = $e->{id};
    my $text   = $e->all_text;
    my $anchor = $c->tag(a => href => "#$id", sub {$text});

    if ($e->type eq 'h1') {
      $ul .= '</ul>' if $sub;
      $sub = 0;
    }
    else {
      $ul .= '<ul>' unless $sub;
      $sub = 1;
    }

    $ul .= "<li>$anchor</li>";

    $e->content($c->link_to($text => Mojo::URL->new->fragment('toc'), id => $id));
  }

  $ul .= '</ul>' if $ul;

  return $c->b(qq(<div class="pod-container"><h1 id="toc">TABLE OF CONTENTS</h1>$ul$dom</div>));
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

$ENV{SWAGGER_LOAD_EDITOR} ? __PACKAGE__->new : 1;

__DATA__
@@ error.html.ep
% title "Error in specification";
<h2>Error in specification</h2>
<pre><%= $error %></pre>

@@ editor.html.ep
% title "Editor";
<div id="editor"><%= stash('raw') || '---' %></div>
<div id="resizer">&nbsp;</div>
<div id="preview"><%= podify $swagger->pod %></div>
% my $ace_url = $c->req->url->base->path->clone;
% push @{$ace_url->parts}, 'ace.js';
<script src="<%= $ace_url %>"></script>
%= javascript begin
(function(ace) {
  var localStorage = window.localStorage || {};
  var draggable = document.getElementById("resizer");
  var editor = document.getElementById("editor");
  var preview = document.getElementById("preview");
  var focusId = location.href.split("#")[1] || "";
  var initializing = true;
  var tid, xhr, i;

  var loaded = function() {
    if (initializing) {
      ace.focus();
      ace.gotoLine(2);
    }
    initializing = false;
    ace.session.setMode("ace/mode/" + (ace.getValue().match(/^\s*\{/) ? "json" : "yaml"));
    preview.scrollTop = scrollSave();
  };

  var render = function() {
    scrollSave();
    xhr = new XMLHttpRequest();
    xhr.open("POST", "<%= url_for("/") %>", true);
    xhr.onload = function() { preview.firstChild.innerHTML = xhr.responseText; loaded(); };
    localStorage["swagger-spec"] = ace.getValue();
    xhr.send(localStorage["swagger-spec"]);
  };

  var scrollSave = function() {
    var elem = document.getElementById(location.href.split("#")[1] || "toc");
    if (!elem) return 0;
    var last = scrollSave.last;
    scrollSave.last = preview.scrollTop || elem.offsetTop;
    return last || scrollSave.last;
  };

  ace.commands.addCommand({ bindKey: { win: "Ctrl-L", mac: "Command-L" }, command: "passKeysToBrowser" });
  ace.commands.addCommand({
    name: "find",
    bindKey: { win: "Ctrl-F", mac: "Command-F" },
    exec: function(editor) { editor.find(prompt("Find:", editor.getCopyText())); }
  });
  ace.setTheme("ace/theme/solarized_dark");
  ace.getSession().on("change", function(e) {
    if (initializing) return;
    if (tid) clearTimeout(tid);
    tid = setTimeout(render, 600);
  });

  if (!focusId) {
    location.href = location.href + "#toc";
  }

  if (focusId.indexOf("/") == 0) {
    xhr = new XMLHttpRequest();
    xhr.open("GET", focusId, true);
    xhr.onload = function() {
      if (!xhr.responseText.match(/^\s*(---|{)/)) return alert("Could not load specification from " + focusId);
      ace.setValue(xhr.responseText);
      render();
    };
    xhr.send(false);
    location.href = location.href.replace(/\#.*/, "#toc");
  }
  else if (localStorage["swagger-spec"]) {
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
    background: #f5f5f5;
    font-family: sans-serif;
    font-size: 14px;
    color: #111;
    margin: 0;
    padding: 0;
    height: 100%;
    width: 100%;
  }
  a { color: #222; }
  p { margin: 0.5em 0; }
  h1, h2, h3 { padding: 0; margin: 1em 0 0 0; }
  h1 { font-size: 2em; }
  h2 { font-size: 1.5em; border-bottom: 1px solid #bbb; }
  h3 { font-size: 1.2em; }
  h4 { font-size: 1em; }
  h1 a, h2 a, h3 a, h4 a { text-decoration: none; }
  h1 a:hover, h2 a:hover, h3 a:hover, h4 a:hover { text-decoration: underline; }
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
