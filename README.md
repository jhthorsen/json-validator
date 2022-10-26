# NAME

JSON::Validator - Validate data against a JSON schema

# SYNOPSIS

## Using a schema object

[JSON::Validator::Schema](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema) or any of the sub classes can be used instead of
[JSON::Validator](https://metacpan.org/pod/JSON%3A%3AValidator). The only reason to use [JSON::Validator](https://metacpan.org/pod/JSON%3A%3AValidator) directly is if
you don't know the schema version up front.

## Basics

    use JSON::Validator;
    my $jv = JSON::Validator->new;

    # Define a schema - http://json-schema.org/learn/miscellaneous-examples.html
    # You can also load schema from disk or web
    $jv->schema({
      type       => "object",
      required   => ["firstName", "lastName"],
      properties => {
        firstName => {type => "string"},
        lastName  => {type => "string"},
        age       => {type => "integer", minimum => 0, description => "Age in years"}
      }
    });

    # Validate your data
    my @errors = $jv->validate({firstName => "Jan Henning", lastName => "Thorsen", age => -42});

    # Do something if any errors was found
    die "@errors" if @errors;

## Using joi

    # Use joi() to build the schema
    use JSON::Validator::Joi 'joi';

    $jv->schema(joi->object->props({
      firstName => joi->string->required,
      lastName  => joi->string->required,
      age       => joi->integer->min(0),
    }));

    # joi() can also validate directly
    my @errors = joi(
      {firstName => "Jan Henning", lastName => "Thorsen", age => -42},
      joi->object->props({
        firstName => joi->string->required,
        lastName  => joi->string->required,
        age       => joi->integer->min(0),
      }),
    );

# DESCRIPTION

[JSON::Validator](https://metacpan.org/pod/JSON%3A%3AValidator) is a data structure validation library based around
[JSON Schema](https://json-schema.org/). This module can be used directly with
a JSON schema or you can use the elegant DSL schema-builder
[JSON::Validator::Joi](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3AJoi) to define the schema programmatically.

## Supported schema formats

[JSON::Validator](https://metacpan.org/pod/JSON%3A%3AValidator) can load JSON schemas in multiple formats: Plain perl data
structured (as shown in ["SYNOPSIS"](#synopsis)), JSON or YAML. The JSON parsing is done
with [Mojo::JSON](https://metacpan.org/pod/Mojo%3A%3AJSON), while YAML files requires [YAML::PP](https://metacpan.org/pod/YAML%3A%3APP) or [YAML::XS](https://metacpan.org/pod/YAML%3A%3AXS).

## Resources

Here are some resources that are related to JSON schemas and validation:

- [http://json-schema.org/documentation.html](http://json-schema.org/documentation.html)
- [https://json-schema.org/understanding-json-schema/index.html](https://json-schema.org/understanding-json-schema/index.html)
- [https://github.com/json-schema/json-schema/](https://github.com/json-schema/json-schema/)

## Bundled specifications

This module comes with some JSON specifications bundled, so your application
don't have to fetch those from the web. These specifications should be up to
date, but please submit an issue if they are not.

Files referenced to an URL will automatically be cached if the first element in
["cache\_paths"](#cache_paths) is a writable directory. Note that the cache headers for the
remote assets are **not** honored, so you will manually need to remove any
cached file, should you need to refresh them.

To download and cache an online asset, do this:

    JSON_VALIDATOR_CACHE_PATH=/some/writable/directory perl myapp.pl

Here is the list of the bundled specifications:

- JSON schema, draft 4, 6, 7, 2019-09.

    Web page: [http://json-schema.org](http://json-schema.org)

    `$ref`: [http://json-schema.org/draft-04/schema#](http://json-schema.org/draft-04/schema#),
    [http://json-schema.org/draft-06/schema#](http://json-schema.org/draft-06/schema#),
    [http://json-schema.org/draft-07/schema#](http://json-schema.org/draft-07/schema#).

- JSON schema for JSONPatch files

    Web page: [http://jsonpatch.com](http://jsonpatch.com)

    `$ref`: [http://json.schemastore.org/json-patch#](http://json.schemastore.org/json-patch#)

- Swagger / OpenAPI specification, version 2

    Web page: [https://openapis.org](https://openapis.org)

    `$ref`: [http://swagger.io/v2/schema.json#](http://swagger.io/v2/schema.json#)

- OpenAPI specification, version 3

    Web page: [https://openapis.org](https://openapis.org)

    `$ref`: [https://spec.openapis.org/oas/3.0/schema/2019-04-02](https://github.com/OAI/OpenAPI-Specification/blob/master/schemas/v3.0/schema.json)

    This specification is still EXPERIMENTAL.

- Swagger Petstore

    This is used for unit tests, and should not be relied on by external users.

## Optional modules

- Sereal::Encoder

    Installing [Sereal::Encoder](https://metacpan.org/pod/Sereal%3A%3AEncoder) v4.00 (or later) will make
    ["data\_checksum" in JSON::Validator::Util](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3AUtil#data_checksum) significantly faster. This function is
    used both when parsing schemas and validating data.

- Format validators

    See the documentation in [JSON::Validator::Formats](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3AFormats) for other optional modules
    to do validation of specific "format", such as "hostname", "ipv4" and others.

# ATTRIBUTES

## cache\_paths

Proxy attribute for ["cache\_paths" in JSON::Validator::Store](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3AStore#cache_paths).

## formats

This attribute will be used as default value for
["formats" in JSON::Validator::Schema](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema#formats). It is highly recommended to change this
directly on the ["schema"](#schema) instead:

    $jv->formats(...);         # Legacy
    $jv->schema->formats(...); # Recommended way

## recursive\_data\_protection

This attribute will be used as default value for
["recursive\_data\_protection" in JSON::Validator::Schema](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema#recursive_data_protection). It is highly recommended
to change this directly on the ["schema"](#schema) instead:

    $jv->recursive_data_protection(...);         # Legacy
    $jv->schema->recursive_data_protection(...); # Recommended way

## store

    $store = $jv->store;

Holds a [JSON::Validator::Store](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3AStore) object that caches the retrieved schemas.
This object will be shared amongst different ["schema"](#schema) objects to prevent
a schema from having to be downloaded again.

## ua

Proxy attribute for ["ua" in JSON::Validator::Store](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3AStore#ua).

# METHODS

## bundle

This method can be used to get a bundled version of ["schema"](#schema). It will however
return a data-structure instead of a new object. See
["bundle" in JSON::Validator::Schema](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema#bundle) for an alternative.

    # These two lines does the same
    $data = $jv->bundle;
    $data = $jv->schema->bundle->data;

    # Recommended way
    $schema = $jv->schema->bundle;

## coerce

This attribute will be used as default value for
["coerce" in JSON::Validator::Schema](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema#coerce). It is highly recommended to change this
directly on the ["schema"](#schema) instead:

    $jv->coerce(...);         # Legacy
    $jv->schema->coerce(...); # Recommended way

## get

Proxy method for ["get" in JSON::Validator::Schema](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema#get).

## new

    $jv = JSON::Validator->new(%attributes);
    $jv = JSON::Validator->new(\%attributes);

Creates a new [JSON::Validate](https://metacpan.org/pod/JSON%3A%3AValidate) object.

## load\_and\_validate\_schema

This method will be deprecated in the future. See
["errors" in JSON::Validator::Schema](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema#errors) and ["is\_invalid" in JSON::Validator::Schema](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema#is_invalid)
instead.

## schema

    $jv     = $jv->schema($json_or_yaml_string);
    $jv     = $jv->schema($url);
    $jv     = $jv->schema(\%schema);
    $jv     = $jv->schema(JSON::Validator::Joi->new);
    $jv     = $jv->schema(JSON::Validator::Schema->new);
    $schema = $jv->schema;

Used to set a schema from either a data structure or a URL.

`$schema` will be an instance of [JSON::Validator::Schema::Draft4](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema%3A%3ADraft4),
[JSON::Validator::Schema::Draft6](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema%3A%3ADraft6) [JSON::Validator::Schema::Draft7](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema%3A%3ADraft7),
[JSON::Validator::Schema::Draft201909](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema%3A%3ADraft201909), [JSON::Validator::Schema::OpenAPIv2](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema%3A%3AOpenAPIv2),
[JSON::Validator::Schema::OpenAPIv3](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema%3A%3AOpenAPIv3) or [JSON::Validator::Schema](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema).

The `$url` can take many forms, but needs to point to a text file in the
JSON or YAML format.

- file://...

    A file on disk. Note that it is required to use the "file" scheme if you want
    to reference absolute paths on your file system.

- http://... or https://...

    A web resource will be fetched using the [Mojo::UserAgent](https://metacpan.org/pod/Mojo%3A%3AUserAgent), stored in ["ua"](#ua).

- data://Some::Module/spec.json

    Will load a given "spec.json" file from `Some::Module` using
    ["data\_section" in JSON::Validator::Util](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3AUtil#data_section).

- data:///spec.json

    A "data" URL without a module name will use the current package and search up
    the call/inheritance tree.

- Any other URL

    An URL (without a recognized scheme) will be treated as a path to a file on
    disk. If the file could not be found on disk and the path starts with "/", then
    the will be loaded from the app defined in ["ua"](#ua). Something like this:

        $jv->ua->server->app(MyMojoApp->new);
        $jv->ua->get('/any/other/url.json');

## validate

Proxy method for ["validate" in JSON::Validator::Schema](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema#validate).

# SEE ALSO

- [JSON::Validator::Formats](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3AFormats)

    [JSON::Validator::Formats](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3AFormats) contains utility functions for validating data
    types. Could be useful for validating data without loading a schema.

- [JSON::Validator::Schema](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema)

    [JSON::Validator::Schema](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema) is the base class for
    [JSON::Validator::Schema::Draft4](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema%3A%3ADraft4), [JSON::Validator::Schema::Draft6](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema%3A%3ADraft6)
    [JSON::Validator::Schema::Draft7](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema%3A%3ADraft7), [JSON::Validator::Schema::Draft201909](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema%3A%3ADraft201909),
    [JSON::Validator::Schema::OpenAPIv2](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema%3A%3AOpenAPIv2) or [JSON::Validator::Schema::OpenAPIv3](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3ASchema%3A%3AOpenAPIv3).

- [JSON::Validator::Util](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3AUtil)

    [JSON::Validator::Util](https://metacpan.org/pod/JSON%3A%3AValidator%3A%3AUtil) contains many useful function when working with
    schemas.

- [Mojolicious::Plugin::OpenAPI](https://metacpan.org/pod/Mojolicious%3A%3APlugin%3A%3AOpenAPI)

    [Mojolicious::Plugin::OpenAPI](https://metacpan.org/pod/Mojolicious%3A%3APlugin%3A%3AOpenAPI) is a plugin for [Mojolicious](https://metacpan.org/pod/Mojolicious) that utilize
    [JSON::Validator](https://metacpan.org/pod/JSON%3A%3AValidator) and the [OpenAPI specification](https://www.openapis.org/)
    to build routes with input and output validation.

# COPYRIGHT AND LICENSE

Copyright (C) 2014-2021, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

# AUTHORS

## Project Founder

Jan Henning Thorsen - `jhthorsen@cpan.org`

## Contributors

- Aleksandr Orlenko
- Alexander Hartmaier
- Alexander Karelas
- Bernhard Graf
- Brad Barden
- Dagfinn Ilmari Mannsåker
- Daniel Böhmer
- David Cantrell
- Ed J
- Ere Maijala
- Fabrizio Gennari
- Ilya Rassadin
- Jason Cooper
- Karen Etheridge
- Kenichi Ishigaki
- Kevin M. Goess
- Kirill Matusov
- Krasimir Berov
- Lari Taskula
- Lee Johnson
- Martin Renvoize
- Mattias Päivärinta
- Michael Jemmeson
- Michael Schout
- Mohammad S Anwar
- Nick Morrott
- Pierre-Aymeric Masse
- Roy Storey
- Russell Jenkins
- Sebastian Riedel
- Stephan Hradek
- Tim Stallard
- Zoffix Znet
