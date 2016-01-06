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

Mojolicious is an awesome web framework which allow you concentrate on the
business logic, while the rest Just Works (tm).

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
and objects (hashes). It allows you to define rules on top of those basic
building blocks which results in powerful tool for validation.

---
class: center, middle

# JSON::Schema

Toby Inkster, Ben Hutton

### v.s.

# JSON::Validator

Jan Henning Thorsen and friends

???

JSON::Schema is...

---
class: middle

# Why do you want to use Swagger?

* Why not just do validation inside your web app?
* Keeping documentation and code in sync
* Sharing validation rules and documentation between the server and clients

???

This question comes up quite often after telling people about Swagger:
“but…why??” The people asking this often come from the same background as
myself, where you both write the producer (backend web server) and consumer
(javascript, …) code. When you’re in complete control of both sides you don’t
really need to write any formal specification or document your API, since you
already know how it works. This can be very true - at least if you make sure
you have tests of all your endpoints.

Personally I’m a huge fan of documenting as well as testing. I often say that
if you can’t document (describe) the API/method/whatever, something is wrong
and you should reconsider what you’re coding. Documenting an API on the
other hand is awful IMO, especially during rapid prototyping/developing
where it’s hard to keep the code and documentation up to date.

So how does swagger fix this? Since the input/ouput Perl code is generated
from the swagger document, you know that the backend is always running code
accordingly to the specification. Also, since the documentation you generate
is not hand written, but generated from the same swagger document you can know
that the code the server is running is in sync with the documentation.

When “generated code” is mentioned, it’s not just the routing, but also input
and output validation. This means that when any data has made it through to
your controller action, you know that the data is valid. On the other side,
the consumer (let’s say a javascript that cares about the difference between
an integer and string) will know that it has received the correct data, since
invalid output will result in a 500.

So… If you don’t care about documenation or collaberation with others, then
I’m not sure if I would care much about swagger either.

Note that the swagger spec is not just for the server, but can also be used to
generate javascript and perl client side code.

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

BLOG_PG_URL=postgresql://jhthorsen@/test perl script/blog daemon
SWAGGER_BASE_URL=http://localhost:3000 mojo swagger2 client api.json
PERL5LIB=../../lib SWAGGER_BASE_URL=http://localhost:3000/api mojo swagger2 client api.json store '{"entry":{"body":"yay!","title":"demo"}}'
PERL5LIB=../../lib SWAGGER_BASE_URL=http://localhost:3000/api mojo swagger2 client api.json list

---
class: contrast, center, middle

<img src="/img/thank-you.jpg" style="max-height:340px">

irc.perl.org/#swagger

irc.perl.org/batman

@jhthorsen

http://thorsen.pm
