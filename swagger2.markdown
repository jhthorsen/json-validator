class: center, middle

<img src="/img/mojo-love-swagger.png">

???

Hi, My name is Jan Henning Thorsen. I’m a core Mojolicious developer and the
creator of the Swagger integrations in Perl/Mojolicious.  This talk will give
an introduction to Swagger and how you can build Mojolicious applications with
the Swagger spec.

---
class: center, middle

# What is Mojolicious?

<img src="/img/web-fun.png">

???

Mojolicious is an modern web framework which allow you concentrate on the
business logic, while the rest Just Works (tm).

It ships with a template language, a JSON encoder/decoder, HTML/XML parser, a
web user agent, websocket support, session handling and an IO loop which
allows you to handle thousands of concurrent requests.

---
class: center, middle

# What is Swagger?

<img src="/img/what-is-swagger.png">

???

Swagger is “The World’s Most Popular Framework for APIs”. Swagger is a
language for specifying the input and output to your HTTP API. (REST- or RPC
API, if you like). The API rules are based on top of the JSON schema rules,
but extends beyond basic data validation and allows you to define a complete
API spec.

---
class: center, middle

# What is JSON Schema?

<img src="/img/what-is-json-schema.jpg" style="max-height:260px">

???

JSON Schema is a powerful tool for describing and validating the structure of
JSON data. The building blocks in a JSON Schema are strings, numbers, arrays
and objects (hashes). Swagger allows you to define rules on top of those basic
building blocks which results in powerful tool for validation and as well a
documented API.

---
class: center, middle

# JSON::Schema

Toby Inkster, Ben Hutton

### v.s.

# JSON::Validator

Jan Henning Thorsen and friends

???

JSON::Schema was an existing implementation of the JSON Schema spec, but it
only supported draft 3. This was not sufficient, since Swagger require draft
\4. Since I was unable to get that module up to speed, I decided to implement
a new module called JSON::Validator which support the validation rules in
draft 4.

It used to be part of Swagger2, but I factored the code out since many people
wanted a module just to validate JSON.

---
class: middle

# Why do you want to use Swagger?

* Why not just do validation inside your web app?
* Keeping documentation and code in sync
* Sharing validation rules and documentation between the server and clients

???

This question comes up quite often after telling people about Swagger:
“but...why??” The people asking this often come from the same background as
myself, where you both write the producer (backend web server) and consumer
(javascript, ...) code. When you’re in complete control of both sides you don’t
really need to write any formal specification or document your API, since you
already know how it works. This statement can be very true - at least if you
make sure you have written tests of all your endpoints.

Personally I’m a huge fan of documenting as well as testing. I often say that
if you can’t document (describe) the API/method/whatever, then you should
consider throwing the method away and start over with something you _can_
describe.

Documenting an API used to be very troubling for me. The reason for that is
that there are so many details too keep in sync in multiple places: You need
to _remember_ to update the documentation every time you make a change in the
code.

So how does swagger fix this? Since the input/ouput Perl code is generated
from the swagger document, you know that the backend is always running code
accordingly to the specification. Also, since the documentation you generate
is not hand written, but generated from the same swagger document you can know
that the server is running the code which is in sync with the documentation.

The last thing I like is that you can hand the spec over to someone building a
client for iOS, Android or JavaScript and they can auto generate code, just
like you do in Perl. So sharing the spec is a good idea, since you then know
that the clients run the same code as the server do.

---
class: middle

# Swagger2 distribution

* Swagger2 and JSON::Validator
--

* Swagger2::Client
--

* Swagger2::POD, Swagger2::Markdown
--

* Mojolicious::Command::swagger2
--

* Mojolicious::Plugin::Swagger2

---
class: center, middle

<img src="/img/live-demo.jpg" style="max-height:340px">

---
class: middle

# Demo blog application

```shell
$ git clone https://github.com/jhthorsen/swagger2.git

$ cd swagger2/t/blog/

$ BLOG_PG_URL=postgresql://postgres@/test \
  perl script/blog routes

$ BLOG_PG_URL=postgresql://postgres@/test \
  perl script/blog daemon

$ SWAGGER_BASE_URL=http://localhost:3000 \
  mojo swagger2 client api.json
```

???

file:///Users/jhthorsen/git/demo/swagger2/t/blog/api.json

BLOG_PG_URL=postgresql://jhthorsen@/test perl script/blog routes

BLOG_PG_URL=postgresql://jhthorsen@/test perl script/blog daemon

SWAGGER_BASE_URL=http://localhost:3000 mojo swagger2 client api.json

SWAGGER_BASE_URL=http://localhost:3000/api mojo swagger2 client api.json storePost '{"entry":{"body":"yay!","title":"demo"}

SWAGGER_BASE_URL=http://localhost:3000/api mojo swagger2 client api.json listPosts

SWAGGER_BASE_URL=http://localhost:3000/api mojo swagger2 client api.json removePost '{"id":"1"}'

---
class: contrast, center, middle

<img src="/img/thank-you.jpg" style="max-height:340px">

irc.perl.org/#swagger

irc.perl.org/batman

@jhthorsen

http://thorsen.pm
