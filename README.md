
# JSON::Validator [![Build Status](https://travis-ci.com/mojolicious/json-validator.svg?branch=master)](https://travis-ci.com/mojolicious/mojo-pg)

  A module for validating data against a [JSON Schema](https://json-schema.org/).

```perl
use Mojolicious::Lite -signatures;
use JSON::Validator 'joi';
use Mojo::JSON qw(false true);

post '/users' => sub ($c) {
  my $user = $c->req->json;

  # Validate input JSON document
  my @errors = joi(
    $user,
    joi->object->props(
      email    => joi->email->required,
      username => joi->string->min(1)->required,
      password => joi->string->min(12)->required,
    )
  );

  # Report back on invalid input
  return $c->render(json => {errors => \@errors}, status => 400) if @errors;

  # Handle the $user in some way, like adding the user to a database
  my $created = $c->db->insert('users', $user);

  # Report back the status
  return $c->render(json => {created => $created ? true : false}, status => 201);
};

app->start;
```

## Installation

  All you need is a one-liner, it takes seconds to install.

    $ curl -L https://cpanmin.us | perl - -M https://cpan.metacpan.org -n JSON::Validator

  We recommend the use of a [Perlbrew](http://perlbrew.pl) environment.

## Want to know more?

  Take a look at our excellent
  [documentation](https://mojolicious.org/perldoc/JSON/Validator)!
