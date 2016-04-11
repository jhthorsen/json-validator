#!/usr/bin/env perl
use lib 'lib';
use Mojolicious::Lite;
use t::Api;

# How to run this exampl:
# 1) Run ./examples/websocket.pl daemon --listen http://*:3000
# 2) Open up http://localhost:3000 in your browser.
# 3) Open the developer console in your browser.
# 4) Reload.
# 5) See which requests are passed over the WebSocket or as plain HTTP.

no warnings 'redefine';

sub t::Api::list_pets {
  my ($c, $args, $cb) = @_;
  state $i = 42;
  $c->$cb([{id => $i++, name => "Catwoman"}], 200);
}

get '/' => 'index';

get '/asset/swagger-client' => sub {
  my $c = shift;
  $c->reply->asset(Swagger2->new->javascript_client);
};

my $ws = websocket '/ws' => sub {
  my $c = shift;

  $c->on(
    json => sub {
      my ($c, $data) = @_;
      return if $c->dispatch_to_swagger($data);
    }
  );
};

app->plugin(Swagger2 => {url => 't/data/petstore.json', ws => $ws});

app->start;

__DATA__
@@ index.html.ep
<!doctype html>
<html>
  <head>
    % if (param('ws') // 1) {
      %= link_to "Disable websockets", url_with()->query(ws => 0)
    % } else {
      %= link_to "Enable websockets", url_with()->query(ws => 1)
    % }
    <p id="loading">Loading Swagger spec...</p>
    <p id="loaded"></p>
    <hr>
    <b><%= (param('ws') // 1) ? "WebSocket response" : "Plain HTTP response" %>:</b>
    <span id="pets"></span>
    <hr>
    <b>Plain HTTP response:</b>
    <span id="pets_http"></span>
  </head>
  <body>
    %= javascript '/asset/swagger-client.js';
    %= javascript begin
      var client = new swaggerClient();

      var clientLoaded = function(err) {
        document.getElementById("loaded").innerHTML = err || 'Specification loaded.';
        if (err) return;

        // Request over WebSocket or plain HTTP
        this.listPets({limit: 10}, function(err, xhr) {
          document.getElementById("pets").innerHTML = JSON.stringify(err || xhr.body);
        });

        // Request over plain HTTP
        this.http().listPets({limit: 10}, function(err, xhr) {
          document.getElementById("pets_http").innerHTML = JSON.stringify(err || xhr.body);
        });
      };

      if (location.href.indexOf('ws=0') == -1) {
        var ws    = new WebSocket("<%= url_for('/ws')->to_abs->scheme('ws') %>");
        ws.onopen = function() { client.ws(ws).load("/api", clientLoaded); };
      }
      else {
        client.load("/api", clientLoaded);
      }
    % end
  </body>
</html>
