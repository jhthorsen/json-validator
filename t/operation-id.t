use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use Mojolicious::Lite;
use lib 't/lib';

plugin Swagger2 => {url => 'data://main/petstore.json'};
app->routes->namespaces(['MyApp::Controller']);

my $t = Test::Mojo->new;

$MyApp::Controller::Pet::RES = [{id => 123, name => 'kit-cat'}];
$t->get_ok('/api/pets')->status_is(200)->json_is('/0/id', 123)->json_is('/0/name', 'kit-cat');

$MyApp::Controller::Pet::RES = {name => 'kit-cat'};
$t->post_ok('/api/pets/42')->status_is(200)->json_is('/id', 42)->json_is('/name', 'kit-cat');

for (qw( Person User Bar Pet Conversation Foo Fs FileSystem )) {
  eval "package MyApp::Controller::$_; use Mojo::Base 'Mojolicious::Controller';1" or die $@;
}

is_deeply [ca('childrenOfPerson')],       [qw( MyApp::Controller::Person children )],        'childrenOfPerson';
is_deeply [ca('designByUser')],           [qw( MyApp::Controller::User design )],            'designByUser';
is_deeply [ca('fooWithBar')],             [qw( MyApp::Controller::Bar foo )],                'fooWithBar';
is_deeply [ca('messagesForPet')],         [qw( MyApp::Controller::Pet messages )],           'messagesForPet';
is_deeply [ca('peopleInConversation')],   [qw( MyApp::Controller::Conversation people )],    'peopleInConversation';
is_deeply [ca('sendToConversation')],     [qw( MyApp::Controller::Conversation send )],      'sendToConversation';
is_deeply [ca('showPetsById')],           [qw( MyApp::Controller::Pet show )],               'showPetsById';
is_deeply [ca('deleteFromFoo')],          [qw( MyApp::Controller::Foo delete )],             'deleteFromFoo';
is_deeply [ca('create_fileInFs')],        [qw( MyApp::Controller::Fs create_file )],         'create_fileInFs';
is_deeply [ca('createFileInFileSystem')], [qw( MyApp::Controller::FileSystem create_file )], 'createFileInFileSystem';
is_deeply [ca('removeFromFileSystem')],   [qw( MyApp::Controller::FileSystem remove )],      'removeFromFileSystem';

done_testing;

sub ca {
  my $c = $t->app->controller_class->new(app => $t->app);
  my $m = Mojolicious::Plugin::Swagger2->can('_find_action');
  my $e = $m->($c, {operationId => $_[0]}, my $r = {});
  diag $e if $e and $ENV{SWAGGER2_DEBUG};
  return @$r{qw( controller action )};
}

__DATA__
@@ petstore.json
{
  "swagger": "2.0",
  "info": { "version": "1.0.0", "title": "Swagger Petstore" },
  "basePath": "/api",
  "paths": {
    "/pets": {
      "get": {
        "operationId": "listPets",
        "responses": {
          "200": { "description": "pet response", "schema": { "type": "array", "items": { "$ref": "#/definitions/Pet" } } }
        }
      }
    },
    "/pets/{petId}": {
      "post": {
        "operationId": "showPetById",
        "parameters": [
          {
            "name": "petId",
            "in": "path",
            "required": true,
            "description": "The id of the pet to receive",
            "type": "integer"
          }
        ],
        "responses": {
          "200": { "description": "Expected response to a valid request", "schema": { "$ref": "#/definitions/Pet" } }
        }
      }
    }
  },
  "definitions": {
    "Pet": {
      "required": [ "id", "name" ],
      "properties": {
        "id": { "type": "integer", "format": "int64" },
        "name": { "type": "string" },
        "tag": { "type": "string" }
      }
    }
  }
}
