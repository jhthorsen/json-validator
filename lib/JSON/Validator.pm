package JSON::Validator;
use Mojo::Base -base;

use Carp qw(confess);
use JSON::Validator::Store;
use JSON::Validator::Util qw(E data_checksum is_type);
use Mojo::Util qw(sha1_sum);
use Scalar::Util qw(blessed);

our $VERSION = '5.04';

our %SCHEMAS = (
  'http://json-schema.org/draft-04/schema#'             => '+Draft4',
  'http://json-schema.org/draft-06/schema#'             => '+Draft6',
  'http://json-schema.org/draft-07/schema#'             => '+Draft7',
  'https://json-schema.org/draft/2019-09/schema'        => '+Draft201909',
  'http://swagger.io/v2/schema.json'                    => '+OpenAPIv2',
  'https://spec.openapis.org/oas/3.0/schema/2019-04-02' => '+OpenAPIv3',
  'https://spec.openapis.org/oas/3.1/schema/2021-05-20' => '+OpenAPIv3',
);

has formats                   => sub { require JSON::Validator::Schema; JSON::Validator::Schema->_build_formats };
has recursive_data_protection => 1;

has store => sub {
  my $self = shift;
  my %attrs;
  $attrs{$_} = delete $self->{$_} for grep { $self->{$_} } qw(cache_paths ua);
  return JSON::Validator::Store->new(%attrs);
};

# store proxy attributes
for my $method (qw(cache_paths ua)) {
  Mojo::Util::monkey_patch(__PACKAGE__, $method => sub { shift->store->$method(@_) });
}

sub bundle { shift->schema->bundle(@_)->data }

sub coerce {
  my $self = shift;
  return $self->{coerce} ||= {} unless defined(my $what = shift);

  state $short = {bool => 'booleans', def => 'defaults', num => 'numbers', str => 'strings'};
  $what                                 = {map { ($_ => 1) } split /,/, $what} unless ref $what;
  $self->{coerce}                       = {};
  $self->{coerce}{($short->{$_} || $_)} = $what->{$_} for keys %$what;

  return $self;
}

sub get { shift->schema->get(@_) }

sub load_and_validate_schema {
  my ($self, $schema, $args) = @_;

  delete $self->{schema};
  my $schema_obj = $self->_new_schema($schema, %$args);
  confess join "\n", "Invalid JSON specification", (ref $schema eq 'HASH' ? Mojo::Util::dumper($schema) : $schema),
    map {"- $_"} @{$schema_obj->errors}
    if @{$schema_obj->errors};

  $self->{schema} = $schema_obj;
  return $self;
}

sub new {
  my $self = shift->SUPER::new(@_);
  $self->coerce($self->{coerce}) if defined $self->{coerce};
  return $self;
}

sub schema {
  my $self = shift;
  return $self->{schema} //= $self->_new_schema({}) unless @_;
  $self->{schema} = $self->_new_schema(shift);
  return $self;
}

sub validate {
  my ($self, $data, $schema) = @_;
  return +(defined $schema ? $self->_new_schema($schema) : $self->schema)->validate($_[1]);
}

sub _new_schema {
  my ($self, $source, %attrs) = @_;
  return $source if blessed $source and $source->can('specification');

  # Compat with load_and_validate_schema()
  $attrs{specification} = delete $attrs{schema} if $attrs{schema};

  my $loadable
    = (blessed $source && ($source->can('scheme') || $source->isa('Mojo::File')))
    || ($source !~ /\n/ && -f $source)
    || (!ref $source && $source =~ /^\w/);

  my $store  = $self->store;
  my $schema = $loadable ? $store->get($store->load($source)) : $source;

  $attrs{recursive_data_protection} //= $self->recursive_data_protection;

  $attrs{coerce}  ||= $self->{coerce}  if $self->{coerce};
  $attrs{formats} ||= $self->{formats} if $self->{formats};
  $attrs{specification} = $schema->{'$schema'}
    if !$attrs{specification}
    and is_type $schema, 'HASH'
    and $schema->{'$schema'};
  $attrs{store} = $store;

  # Detect openapiv2 and v3 schemas by content, since no "$schema" is present
  my $spec = $attrs{specification} || $schema;
  if (ref $spec eq 'HASH' and $spec->{paths}) {
    if ($spec->{swagger} and $spec->{swagger} eq '2.0') {
      $spec = 'http://swagger.io/v2/schema.json';
    }
    elsif ($spec->{openapi} and $spec->{openapi} =~ m!^3\.1\.\d+$!) {
      $spec = 'https://spec.openapis.org/oas/3.1/schema/2021-05-20';
      $attrs{specification} ||= $spec;
    }
    elsif ($spec->{openapi} and $spec->{openapi} =~ m!^3\.0\.\d+$!) {
      $spec = 'https://spec.openapis.org/oas/3.0/schema/2019-04-02';
    }
  }

  my $schema_class = $spec && $SCHEMAS{$spec} || 'JSON::Validator::Schema';
  $schema_class =~ s!^\+(.+)$!JSON::Validator::Schema::$1!;
  confess "Could not load $schema_class: $@" unless $schema_class->can('new') or eval "require $schema_class;1";
  return $schema_class->new($source, %attrs);
}

1;

=encoding utf8

=head1 NAME

JSON::Validator - Validate data against a JSON schema

=head1 SYNOPSIS

=head2 Using a schema object

L<JSON::Validator::Schema> or any of the sub classes can be used instead of
L<JSON::Validator>. The only reason to use L<JSON::Validator> directly is if
you don't know the schema version up front.

=head2 Basics

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

=head2 Using joi

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

=head1 DESCRIPTION

L<JSON::Validator> is a data structure validation library based around
L<JSON Schema|https://json-schema.org/>. This module can be used directly with
a JSON schema or you can use the elegant DSL schema-builder
L<JSON::Validator::Joi> to define the schema programmatically.

=head2 Supported schema formats

L<JSON::Validator> can load JSON schemas in multiple formats: Plain perl data
structured (as shown in L</SYNOPSIS>), JSON or YAML. The JSON parsing is done
with L<Mojo::JSON>, while YAML files requires L<YAML::PP> or L<YAML::XS>.

=head2 Resources

Here are some resources that are related to JSON schemas and validation:

=over 4

=item * L<http://json-schema.org/documentation.html>

=item * L<https://json-schema.org/understanding-json-schema/index.html>

=item * L<https://github.com/json-schema/json-schema/>

=back

=head2 Bundled specifications

This module comes with some JSON specifications bundled, so your application
don't have to fetch those from the web. These specifications should be up to
date, but please submit an issue if they are not.

Files referenced to an URL will automatically be cached if the first element in
L</cache_paths> is a writable directory. Note that the cache headers for the
remote assets are B<not> honored, so you will manually need to remove any
cached file, should you need to refresh them.

To download and cache an online asset, do this:

  JSON_VALIDATOR_CACHE_PATH=/some/writable/directory perl myapp.pl

Here is the list of the bundled specifications:

=over 2

=item * JSON schema, draft 4, 6, 7, 2019-09.

Web page: L<http://json-schema.org>

C<$ref>: L<http://json-schema.org/draft-04/schema#>,
L<http://json-schema.org/draft-06/schema#>,
L<http://json-schema.org/draft-07/schema#>.

=item * JSON schema for JSONPatch files

Web page: L<http://jsonpatch.com>

C<$ref>: L<http://json.schemastore.org/json-patch#>

=item * Swagger / OpenAPI specification, version 2

Web page: L<https://openapis.org>

C<$ref>: L<http://swagger.io/v2/schema.json#>

=item * OpenAPI specification, version 3

Web page: L<https://openapis.org>

C<$ref>: L<https://spec.openapis.org/oas/3.0/schema/2019-04-02|https://github.com/OAI/OpenAPI-Specification/blob/master/schemas/v3.0/schema.json>

This specification is still EXPERIMENTAL.

=item * Swagger Petstore

This is used for unit tests, and should not be relied on by external users.

=back

=head2 Optional modules

=over 2

=item * Sereal::Encoder

Installing L<Sereal::Encoder> v4.00 (or later) will make
L<JSON::Validator::Util/data_checksum> significantly faster. This function is
used both when parsing schemas and validating data.

=item * Format validators

See the documentation in L<JSON::Validator::Formats> for other optional modules
to do validation of specific "format", such as "hostname", "ipv4" and others.

=back

=head1 ATTRIBUTES

=head2 cache_paths

Proxy attribute for L<JSON::Validator::Store/cache_paths>.

=head2 formats

This attribute will be used as default value for
L<JSON::Validator::Schema/formats>. It is highly recommended to change this
directly on the L</schema> instead:

  $jv->formats(...);         # Legacy
  $jv->schema->formats(...); # Recommended way

=head2 recursive_data_protection

This attribute will be used as default value for
L<JSON::Validator::Schema/recursive_data_protection>. It is highly recommended
to change this directly on the L</schema> instead:

  $jv->recursive_data_protection(...);         # Legacy
  $jv->schema->recursive_data_protection(...); # Recommended way

=head2 store

  $store = $jv->store;

Holds a L<JSON::Validator::Store> object that caches the retrieved schemas.
This object will be shared amongst different L</schema> objects to prevent
a schema from having to be downloaded again.

=head2 ua

Proxy attribute for L<JSON::Validator::Store/ua>.

=head1 METHODS

=head2 bundle

This method can be used to get a bundled version of L</schema>. It will however
return a data-structure instead of a new object. See
L<JSON::Validator::Schema/bundle> for an alternative.

  # These two lines does the same
  $data = $jv->bundle;
  $data = $jv->schema->bundle->data;

  # Recommended way
  $schema = $jv->schema->bundle;

=head2 coerce

This attribute will be used as default value for
L<JSON::Validator::Schema/coerce>. It is highly recommended to change this
directly on the L</schema> instead:

  $jv->coerce(...);         # Legacy
  $jv->schema->coerce(...); # Recommended way

=head2 get

Proxy method for L<JSON::Validator::Schema/get>.

=head2 new

  $jv = JSON::Validator->new(%attributes);
  $jv = JSON::Validator->new(\%attributes);

Creates a new L<JSON::Validate> object.

=head2 load_and_validate_schema

This method will be deprecated in the future. See
L<JSON::Validator::Schema/errors> and L<JSON::Validator::Schema/is_invalid>
instead.

=head2 schema

  $jv     = $jv->schema($json_or_yaml_string);
  $jv     = $jv->schema($url);
  $jv     = $jv->schema(\%schema);
  $jv     = $jv->schema(JSON::Validator::Joi->new);
  $jv     = $jv->schema(JSON::Validator::Schema->new);
  $schema = $jv->schema;

Used to set a schema from either a data structure or a URL.

C<$schema> will be an instance of L<JSON::Validator::Schema::Draft4>,
L<JSON::Validator::Schema::Draft6> L<JSON::Validator::Schema::Draft7>,
L<JSON::Validator::Schema::Draft201909>, L<JSON::Validator::Schema::OpenAPIv2>,
L<JSON::Validator::Schema::OpenAPIv3> or L<JSON::Validator::Schema>.

The C<$url> can take many forms, but needs to point to a text file in the
JSON or YAML format.

=over 4

=item * file://...

A file on disk. Note that it is required to use the "file" scheme if you want
to reference absolute paths on your file system.

=item * http://... or https://...

A web resource will be fetched using the L<Mojo::UserAgent>, stored in L</ua>.

=item * data://Some::Module/spec.json

Will load a given "spec.json" file from C<Some::Module> using
L<JSON::Validator::Util/data_section>.

=item * data:///spec.json

A "data" URL without a module name will use the current package and search up
the call/inheritance tree.

=item * Any other URL

An URL (without a recognized scheme) will be treated as a path to a file on
disk. If the file could not be found on disk and the path starts with "/", then
the will be loaded from the app defined in L</ua>. Something like this:

  $jv->ua->server->app(MyMojoApp->new);
  $jv->ua->get('/any/other/url.json');

=back

=head2 validate

Proxy method for L<JSON::Validator::Schema/validate>.

=head1 SEE ALSO

=over 2

=item * L<JSON::Validator::Formats>

L<JSON::Validator::Formats> contains utility functions for validating data
types. Could be useful for validating data without loading a schema.

=item * L<JSON::Validator::Schema>

L<JSON::Validator::Schema> is the base class for
L<JSON::Validator::Schema::Draft4>, L<JSON::Validator::Schema::Draft6>
L<JSON::Validator::Schema::Draft7>, L<JSON::Validator::Schema::Draft201909>,
L<JSON::Validator::Schema::OpenAPIv2> or L<JSON::Validator::Schema::OpenAPIv3>.

=item * L<JSON::Validator::Util>

L<JSON::Validator::Util> contains many useful function when working with
schemas.

=item * L<Mojolicious::Plugin::OpenAPI>

L<Mojolicious::Plugin::OpenAPI> is a plugin for L<Mojolicious> that utilize
L<JSON::Validator> and the L<OpenAPI specification|https://www.openapis.org/>
to build routes with input and output validation.

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014-2021, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

Daniel Böhmer - C<post@daniel-boehmer.de>

Ed J - C<mohawk2@users.noreply.github.com>

Karen Etheridge - C<ether@cpan.org>

Kevin Goess - C<cpan@goess.org>

Martin Renvoize - C<martin.renvoize@gmail.com>

=cut
