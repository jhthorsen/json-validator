package JSON::Validator;

=head1 NAME

JSON::Validator - Validate data against a JSON schema

=head1 VERSION

0.52

=head1 SYNOPSIS

  use JSON::Validator;
  my $validator = JSON::Validator->new;

  # Define a schema - http://json-schema.org/examples.html
  # You can also load schema from disk or web
  $validator->schema(
    {
      type       => "object",
      required   => ["firstName", "lastName"],
      properties => {
        firstName => {type => "string"},
        lastName  => {type => "string"},
        age       => {type => "integer", minimum => 0, description => "Age in years"}
      }
    }
  );

  # Validate your data
  @errors = $validator->validate({firstName => "Jan Henning", lastName => "Thorsen", age => -42});

  # Do something if any errors was found
  die "@errors" if @errors;

=head1 DESCRIPTION

L<JSON::Validator> is a class for validating data against JSON schemas.
You might want to use this instead of L<JSON::Schema> if you need to
validate data against L<draft 4|https://github.com/json-schema/json-schema/tree/master/draft-04>
of the specification.

This module is currently EXPERIMENTAL. Hopefully nothing drastic will change,
but it needs to fit together nicely with L<Swagger2> - Since this is a spin-off
project.

=head2 Supported schema formats

L<JSON::Validator> can load JSON schemas in multiple formats: Plain perl data
structured (as shown in L</SYNOPSIS>) or files on disk/web in the JSON/YAML
format. The JSON parsing is done using L<Mojo::JSON>, while the YAML parsing
is done with an optional modules which need to be installed manually.
L<JSON::Validator> will look for the YAML modules in this order: L<YAML::XS>,
L<YAML::Syck>, L<YAML::Tiny>, L<YAML>. The order is set by which module that
performs the best, so it might change in the future.

=head2 Resources

Here are some resources that are related to JSON schemas and validation:

=over 4

=item * L<http://json-schema.org/documentation.html>

=item * L<http://spacetelescope.github.io/understanding-json-schema/index.html>

=item * L<http://jsonary.com/documentation/json-schema/>

=item * L<https://github.com/json-schema/json-schema/>

=item * L<Swagger2>

=back

=cut

use Mojo::Base -base;
use Exporter 'import';
use Mojo::JSON;
use Mojo::JSON::Pointer;
use Mojo::URL;
use Mojo::Util;
use B;
use File::Basename ();
use File::Spec;
use Scalar::Util;

use constant VALIDATE_HOSTNAME => eval 'require Data::Validate::Domain;1';
use constant VALIDATE_IP       => eval 'require Data::Validate::IP;1';
use constant IV_SIZE           => eval 'require Config;$Config::Config{ivsize}';

use constant DEBUG => $ENV{JSON_VALIDATOR_DEBUG} || $ENV{SWAGGER2_DEBUG} || 0;
use constant WARN_ON_MISSING_FORMAT => $ENV{JSON_VALIDATOR_WARN_ON_MISSING_FORMAT}
  || $ENV{SWAGGER2_WARN_ON_MISSING_FORMAT} ? 1 : 0;

our $VERSION   = '0.52';
our @EXPORT_OK = qw( validate_json );

sub E { bless {path => $_[0] || '/', message => $_[1]}, 'JSON::Validator::Error'; }
sub S { Mojo::Util::md5_sum(Data::Dumper->new([@_])->Sortkeys(1)->Useqq(1)->Dump); }

=head1 FUNCTIONS

=head2 validate_json

  use JSON::Validator "validate_json";
  @errors = validate_json $data, $schema;

This can be useful in web applications:

  @errors = validate_json $c->req->json, "data://main/spec.json";

=cut

sub validate_json {
  __PACKAGE__->singleton->schema($_[1])->validate($_[0]);
}

=head1 ATTRIBUTES

=head2 cache_dir

  $self = $self->cache_dir($path);
  $path = $self->cache_dir;

Path to where downloaded spec files should be cached. Defaults to
C<JSON_VALIDATOR_CACHE_DIR> or the bundled spec files that are shipped
with this distribution.

=head2 coerce

  $self = $self->coerce(1);
  $bool = $self->coerce;

Set this to true if you want to coerce numbers into string and the other way around.

This is EXPERIMENTAL and could be removed without notice!

=head2 formats

  $hash_ref = $self->formats;
  $self = $self->formats(\%hash);

Holds a hash-ref, where the keys are supported JSON type "formats", and
the values holds a code block which can validate a given format.

Note! The modules mentioned below are optional.

=over 4

=item * byte

A padded, base64-encoded string of bytes, encoded with a URL and filename safe
alphabet. Defined by RFC4648.

=item * date

An RFC3339 date in the format YYYY-MM-DD

=item * date-time

An RFC3339 timestamp in UTC time. This is formatted as
"YYYY-MM-DDThh:mm:ss.fffZ". The milliseconds portion (".fff") is optional

=item * double

Cannot test double values with higher precision then what
the "number" type already provides.

=item * email

Validated against the RFC5322 spec.

=item * float

Will always be true if the input is a number, meaning there is no difference
between  L</float> and L</double>. Patches are welcome.

=item * hostname

Will be validated using L<Data::Validate::Domain> if installed.

=item * int32

A signed 32 bit integer.

=item * int64

A signed 64 bit integer. Note: This check is only available if Perl is
compiled to use 64 bit integers.

=item * ipv4

Will be validated using L<Data::Validate::IP> if installed or
fall back to a plain IPv4 IP regex.

=item * ipv6

Will be validated using L<Data::Validate::IP> if installed.

=item * uri

Validated against the RFC3986 spec.

=back

=head2 ua

  $ua = $self->ua;
  $self = $self->ua(Mojo::UserAgent->new);

Holds a L<Mojo::UserAgent> object, used by L</schema> to load a JSON schema
from remote location.

Note that the default L<Mojo::UserAgent> will detect proxy settings and have
L<Mojo::UserAgent/max_redirects> set to 3. (These settings are EXPERIMENTAL
and might change without a warning)

=cut

has cache_dir => sub {
  $ENV{JSON_VALIDATOR_CACHE_DIR} || File::Spec->catdir(File::Basename::dirname(__FILE__), qw( JSON Validator ));
};

has coerce => $ENV{JSON_VALIDATOR_COERCE_VALUES} || $ENV{SWAGGER_COERCE_VALUES} || 0;    # EXPERIMENTAL!

has formats => sub {
  +{
    'byte'      => \&_is_byte_string,
    'date'      => \&_is_date,
    'date-time' => \&_is_date_time,
    'double'    => sub {1},
    'float'     => sub {1},
    'email'     => \&_is_email,
    'hostname'  => VALIDATE_HOSTNAME ? \&Data::Validate::Domain::is_domain : \&_is_domain,
    'int32'     => sub { _is_number($_[0], 'l'); },
    'int64'     => IV_SIZE >= 8 ? sub { _is_number($_[0], 'q'); } : sub {1},
    'ipv4' => VALIDATE_IP ? \&Data::Validate::IP::is_ipv4 : \&_is_ipv4,
    'ipv6' => VALIDATE_IP ? \&Data::Validate::IP::is_ipv6 : \&_is_ipv6,
    'uri'  => \&_is_uri,
  };
};

has ua => sub {
  require Mojo::UserAgent;
  my $ua = Mojo::UserAgent->new;
  $ua->proxy->detect;
  $ua->max_redirects(3);
  $ua;
};

=head1 METHODS

=head2 schema

  $self = $self->schema(\%schema);
  $self = $self->schema($url);
  $schema = $self->schema;

Used to set a schema from either a data structure or a URL.

C<$schema> will be a L<Mojo::JSON::Pointer> object when loaded,
and C<undef> by default.

The C<$url> can take many forms, but needs to point to a text file in the
JSON or YAML format.

=over 4

=item * http://... or https://...

A web resource will be fetched using the L<Mojo::UserAgent>, stored in L</ua>.

=item * data://Some::Module/file.name

This version will use L<Mojo::Loader/data_section> to load "file.name" from
the module "Some::Module".

=item * /path/to/file

An URL (without a recognized scheme) will be loaded from disk.

=back

=cut

sub schema {
  my ($self, $schema) = @_;

  if (@_ == 1) {
    return $self->{schema};
  }
  elsif (ref $schema eq 'HASH') {
    $self->_register_document($schema, $schema->{id} ||= 'http://generated.json.validator.url#');
  }
  else {
    $schema = $self->_load_schema($schema)->data;
  }

  $self->{schema} = Mojo::JSON::Pointer->new($self->_resolve_schema($schema, $schema->{id}, {}));
  $self;
}

=head2 singleton

  $self = $class->singleton;

Returns the L<JSON::Validator> object used by L</validate_json>.

=cut

sub singleton { state $validator = shift->new }

=head2 validate

  @errors = $self->validate($data);

Validates C<$data> against a given JSON L</schema>. C<@errors> will
contain validation error objects. It will be
empty on success.

Example error object:

  bless {
    message => "Some description",
    path => "/json/path/to/node",
  }, "JSON::Validator::Error"

The error objects are always true in boolean context and will stringify. The
stringification format is subject to change.

=cut

sub validate {
  my ($self, $data, $schema) = @_;
  $schema ||= $self->schema->data;    # back compat with Swagger2::SchemaValidator
  return E '/', 'No validation rules defined.' unless $schema and %$schema;
  return $self->_validate($data, '', $schema);
}

sub _coerce_by_collection_format {
  my ($self, $schema, $data) = @_;
  my $format = $schema->{collectionFormat};
  my @data = $format eq 'ssv' ? split / /, $data : $format eq 'tsv' ? split /\t/,
    $data : $format eq 'pipes' ? split /\|/, $data : split /,/, $data;

  return [map { $_ + 0 } @data] if $schema->{type} and $schema->{type} =~ m!^(integer|number)$!;
  return \@data;
}

sub _load_schema {
  my ($self, $url) = @_;
  my ($namespace, $scheme) = ("$url", "file");
  my $doc;

  if ($namespace =~ m!^https?://!) {
    $url = Mojo::URL->new($url);
    ($namespace, $scheme) = ($url->clone->fragment(undef)->port(undef)->to_string, $url->scheme);
  }
  elsif ($namespace =~ m!^data://(.*)!) {
    $scheme = 'data';
  }

  # Make sure we create the correct namespace if not already done by Mojo::URL
  $namespace =~ s!#.*$!! if $namespace eq $url;

  return $self->{cached}{$namespace} if $self->{cached}{$namespace};
  return eval {
    warn "[JSON::Validator] Loading schema from $url ($namespace)\n" if DEBUG;
    $doc
      = $scheme eq 'file' ? Mojo::Util::slurp($namespace)
      : $scheme eq 'data' ? $self->_load_schema_from_data($url, $namespace)
      :                     $self->_load_schema_from_url($url, $namespace);
    $self->_register_document($self->_load_schema_from_text($doc), $namespace);
  } || do {
    die "Could not load document from $url: $@ ($doc)" if DEBUG;
    die "Could not load document from $url: $@";
  };
}

sub _load_schema_from_data {
  my ($self, $url, $namespace) = @_;
  require Mojo::Loader;
  $namespace =~ m!^data://([^/]+)/(.*)$!;
  Mojo::Loader::data_section($1 || 'main', $2 || $namespace);
}

sub _load_schema_from_text {
  $_[1] =~ /^\s*\{/s ? Mojo::JSON::decode_json($_[1]) : _load_yaml($_[1]);
}

sub _load_schema_from_url {
  my ($self, $url, $namespace) = @_;
  my $cache_file = File::Spec->catfile($self->cache_dir, Mojo::Util::md5_sum($namespace));

  return Mojo::Util::slurp($cache_file) if -r $cache_file;
  my $doc = $self->ua->get($url)->res->body;
  Mojo::Util::spurt($doc, $cache_file) if $self->cache_dir and -w $self->cache_dir;
  return $doc;
}

sub _register_document {
  my ($self, $doc, $namespace) = @_;

  $doc = Mojo::JSON::Pointer->new($doc);
  $namespace = Mojo::URL->new($namespace) unless ref $namespace;
  $namespace->fragment(undef)->port(undef);

  warn "[JSON::Validator] Register $namespace\n" if DEBUG;

  $self->{cached}{$namespace} = $doc;
  $doc->data->{id} ||= "$namespace";
  $self->{cached}{$doc->data->{id}} = $doc;
  $doc;
}

sub _resolve_ref {
  my ($self, $ref, $namespace, $refs) = @_;

  return if !$ref or ref $ref;
  $ref = "#/definitions/$ref" if $ref =~ /^\w+$/;
  $ref = Mojo::URL->new($namespace)->fragment($ref) if $ref =~ s!^\#!!;
  $ref = Mojo::URL->new($ref) unless UNIVERSAL::isa($ref, 'Mojo::URL');

  return $refs->{$ref} if $refs->{$ref};

  warn "[JSON::Validator] Resolve $ref\n" if DEBUG;
  $refs->{$ref} = {};
  my $doc = $self->_load_schema($ref);
  my $def = $self->_resolve_schema($doc->get($ref->fragment), $doc->data->{id}, $refs);
  delete $def->{id};
  $refs->{$ref}{$_} = $def->{$_} for keys %$def;
  $refs->{$ref};
}

sub _resolve_schema {
  my ($self, $obj, $namespace, $refs) = @_;
  my $copy = ref $obj eq 'ARRAY' ? [] : {};
  my $ref;

  if (ref $obj eq 'HASH') {
    $obj = $ref if $ref = $self->_resolve_ref($obj->{'$ref'}, $namespace, $refs);
    $copy->{$_} = $self->_resolve_schema($obj->{$_}, $namespace, $refs) for keys %$obj;
    delete $copy->{'$ref'};
    return $copy;
  }
  elsif (ref $obj eq 'ARRAY') {
    $copy->[$_] = $self->_resolve_schema($obj->[$_], $namespace, $refs) for 0 .. @$obj - 1;
    return $copy;
  }

  return $obj;
}

sub _validate {
  my ($self, $data, $path, $schema) = @_;
  my $type = $schema->{type} || _guess_schema_type($schema, $data);
  my @errors;

  # Test base schema before allOf, anyOf or oneOf
  if (ref $type eq 'ARRAY') {
    for my $type (@$type) {
      my $method = sprintf '_validate_type_%s', $type;
      my @e = $self->$method($data, $path, $schema);
      warn "[JSON::Validator] type @{[$path||'/']} => $method [@e]\n" if DEBUG == 2;
      push @errors, \@e;
      next if @e;
      @errors = ();
      last;
    }
  }
  elsif ($type) {
    my $method = sprintf '_validate_type_%s', $type;
    @errors = $self->$method($data, $path, $schema);
    warn "[JSON::Validator] type @{[$path||'/']} $method [@errors]\n" if DEBUG == 2;
    return @errors if @errors;
  }

  if (my $rules = $schema->{not}) {
    push @errors, $self->_validate($data, $path, $rules);
    warn "[JSON::Validator] not @{[$path||'/']} == [@errors]\n" if DEBUG == 2;
    return @errors ? () : (E $path, 'Should not match.');
  }

  if (my $rules = $schema->{allOf}) {
    push @errors, $self->_validate_all_of($data, $path, $rules);
  }
  elsif ($rules = $schema->{anyOf}) {
    push @errors, $self->_validate_any_of($data, $path, $rules);
  }
  elsif ($rules = $schema->{oneOf}) {
    push @errors, $self->_validate_one_of($data, $path, $rules);
  }

  if (@errors > 1) {
    my %err;
    for my $i (0 .. @errors - 1) {
      for my $e (@{$errors[$i]}) {
        if ($e->{message} =~ m!Expected ([^\.]+)\ - got ([^\.]+)\.!) {
          push @{$err{$e->{path}}}, [$i, $e->{message}, $1, $2];
        }
        else {
          push @{$err{$e->{path}}}, [$i, $e->{message}];
        }
      }
    }
    unshift @errors, [];
    for my $p (sort keys %err) {
      my %uniq;
      my @e = grep { !$uniq{$_->[1]}++ } @{$err{$p}};
      if (@e == grep { defined $_->[2] } @e) {
        push @{$errors[0]}, E $p, sprintf 'Expected %s - got %s.', join(', ', map { $_->[2] } @e), $e[0][3];
      }
      else {
        push @{$errors[0]}, E $p, join ' ', map {"[$_->[0]] $_->[1]"} @e;
      }
    }
  }

  return @{$errors[0]} if @errors and ref $errors[0] eq 'ARRAY';
  return @errors;
}

sub _validate_all_of {
  my ($self, $data, $path, $rules) = @_;
  my @errors;

  for my $rule (@$rules) {
    push @errors, [$self->_validate($data, $path, $rule)];
  }

  warn "[JSON::Validator] allOf @{[$path||'/']} == [@errors]\n" if DEBUG == 2;
  return @errors;
}

sub _validate_any_of {
  my ($self, $data, $path, $rules) = @_;
  my @errors;

  for my $rule (@$rules) {
    my @e = $self->_validate($data, $path, $rule);
    last unless @e;
    push @errors, \@e;
  }

  if (@errors < @$rules) {
    warn "[JSON::Validator] anyOf @{[$path||'/']} == success\n" if DEBUG == 2;
    return;
  }
  else {
    warn "[JSON::Validator] anyOf @{[$path||'/']} == [@errors]\n" if DEBUG == 2;
    return @errors;
  }
}

sub _validate_one_of {
  my ($self, $data, $path, $rules) = @_;
  my $failed = 0;
  my @errors;

  for my $rule (@$rules) {
    my @e = $self->_validate($data, $path, $rule);
    $failed++ if @e;
    push @errors, @e;
  }

  if ($failed + 1 == @$rules) {
    warn "[JSON::Validator] oneOf @{[$path||'/']} == success\n" if DEBUG == 2;
    return;
  }

  warn "[JSON::Validator] oneOf @{[$path||'/']} == failed=$failed/@{[int @$rules]} / @errors\n" if DEBUG == 2;
  return E $path, 'Expected only one to match.';
}

sub _validate_type_enum {
  my ($self, $data, $path, $schema) = @_;
  my $enum = $schema->{enum};
  my $m    = S $data;

  for my $i (@$enum) {
    return if $m eq S $i;
  }

  local $" = ', ';
  return E $path, "Not in enum list: @$enum.";
}

# TODO: Need to figure out if this is a Swagger specific thing
sub _validate_type_file { }

sub _validate_format {
  my ($self, $value, $path, $schema) = @_;
  my $code = $self->formats->{$schema->{format}};

  unless ($code) {
    warn "Format rule for '$schema->{format}' is missing" if WARN_ON_MISSING_FORMAT;
    return;
  }

  return if $code->($value);
  return E $path, "Does not match $schema->{format} format.";
}

sub _validate_type_any {
  return;
}

sub _validate_type_array {
  my ($self, $data, $path, $schema) = @_;
  my @errors;

  if (ref $schema->{items} eq 'HASH' and $schema->{items}{collectionFormat}) {
    $data = $self->_coerce_by_collection_format($schema->{items}, $data);
  }
  if (ref $data ne 'ARRAY') {
    return E $path, _expected(array => $data);
  }

  $data = [@$data];

  if (defined $schema->{minItems} and $schema->{minItems} > @$data) {
    push @errors, E $path, sprintf 'Not enough items: %s/%s.', int @$data, $schema->{minItems};
  }
  if (defined $schema->{maxItems} and $schema->{maxItems} < @$data) {
    push @errors, E $path, sprintf 'Too many items: %s/%s.', int @$data, $schema->{maxItems};
  }
  if ($schema->{uniqueItems}) {
    my %uniq;
    for (@$data) {
      next if !$uniq{S($_)}++;
      push @errors, E $path, 'Unique items required.';
      last;
    }
  }
  if (ref $schema->{items} eq 'ARRAY') {
    my $additional_items = $schema->{additionalItems} // {type => 'any'};
    my @v = @{$schema->{items}};

    if ($additional_items) {
      push @v, $additional_items while @v < @$data;
    }

    if (@v == @$data) {
      for my $i (0 .. @v - 1) {
        push @errors, $self->_validate($data->[$i], "$path/$i", $v[$i]);
      }
    }
    elsif (!$additional_items) {
      push @errors, E $path, sprintf "Invalid number of items: %s/%s.", int(@$data), int(@v);
    }
  }
  elsif (ref $schema->{items} eq 'HASH') {
    for my $i (0 .. @$data - 1) {
      if ($schema->{items}{properties}) {
        push @errors, $self->_validate_type_object($data->[$i], "$path/$i", $schema->{items});
      }
      else {
        push @errors, $self->_validate($data->[$i], "$path/$i", $schema->{items});
      }
    }
  }

  return @errors;
}

sub _validate_type_boolean {
  my ($self, $value, $path, $schema) = @_;

  return if defined $value and Scalar::Util::blessed($value) and ("$value" eq "1" or "$value" eq "0");
  return E $path, _expected(boolean => $value);
}

sub _validate_type_integer {
  my ($self, $value, $path, $schema) = @_;
  my @errors = $self->_validate_type_number($value, $path, $schema, 'integer');

  return @errors if @errors;
  return if $value =~ /^-?\d+$/;
  return E $path, "Expected integer - got number.";
}

sub _validate_type_null {
  my ($self, $value, $path, $schema) = @_;

  return E $path, 'Not null.' if defined $value;
  return;
}

sub _validate_type_number {
  my ($self, $value, $path, $schema, $expected) = @_;
  my @errors;

  $expected ||= 'number';

  if (!defined $value or ref $value) {
    return E $path, _expected($expected => $value);
  }
  unless (B::svref_2object(\$value)->FLAGS & (B::SVp_IOK | B::SVp_NOK) and 0 + $value eq $value and $value * 0 == 0) {
    return E $path, "Expected $expected - got string." if !$self->coerce or $value =~ /\D/;
    $_[1] = 0 + $value;    # coerce input value
  }

  if ($schema->{format}) {
    push @errors, $self->_validate_format($value, $path, $schema);
  }
  if (my $e = _cmp($schema->{minimum}, $value, $schema->{exclusiveMinimum}, '<')) {
    push @errors, E $path, "$value $e minimum($schema->{minimum})";
  }
  if (my $e = _cmp($value, $schema->{maximum}, $schema->{exclusiveMaximum}, '>')) {
    push @errors, E $path, "$value $e maximum($schema->{maximum})";
  }
  if (my $d = $schema->{multipleOf}) {
    unless (int($value / $d) == $value / $d) {
      push @errors, E $path, "Not multiple of $d.";
    }
  }

  return @errors;
}

sub _validate_type_object {
  my ($self, $data, $path, $schema) = @_;
  my ($additional, @errors, %rules);

  if (ref $data ne 'HASH') {
    return E $path, _expected(object => $data);
  }
  if (defined $schema->{maxProperties} and $schema->{maxProperties} < keys %$data) {
    push @errors, E $path, sprintf 'Too many properties: %s/%s.', int(keys %$data), $schema->{maxProperties};
  }
  if (defined $schema->{minProperties} and $schema->{minProperties} > keys %$data) {
    push @errors, E $path, sprintf 'Not enough properties: %s/%s.', int(keys %$data), $schema->{minProperties};
  }

  while (my ($k, $r) = each %{$schema->{properties}}) {
    push @{$rules{$k}}, $r if exists $data->{$k} or $r->{required};
  }
  while (my ($p, $r) = each %{$schema->{patternProperties}}) {
    push @{$rules{$_}}, $r for grep { $_ =~ /$p/ } keys %$data;
  }

  # special case used internally
  $rules{id} ||= [{type => 'string'}] if !$path and $data->{id};
  $additional = exists $schema->{additionalProperties} ? $schema->{additionalProperties} : {};

  if ($additional) {
    $additional = {} unless ref $additional eq 'HASH';
    $rules{$_} ||= [$additional] for keys %$data;
  }
  elsif (my @keys = grep { !$rules{$_} } keys %$data) {
    local $" = ', ';
    return E $path, "Properties not allowed: @keys.";
  }

  if (ref $schema->{required} eq 'ARRAY') {
    for my $k (@{$schema->{required}}) {
      push @{$rules{$k}}, {required => 1};
    }
  }

  for my $k (keys %rules) {
    for my $r (@{$rules{$k}}) {
      if (!exists $data->{$k} and exists $schema->{default}) {
        $data->{$k} = $r->{default};
      }
      if ($r->{required} and !exists $data->{$k}) {
        push @errors, E _path($path, $k), 'Missing property.';
      }
      else {
        push @errors, $self->_validate_type_enum($data->{$k}, _path($path, $k), $r) if $r->{enum};
        push @errors, $self->_validate($data->{$k}, _path($path, $k), $r);
      }
    }
  }

  return @errors;
}

sub _validate_type_string {
  my ($self, $value, $path, $schema) = @_;
  my @errors;

  if (!defined $value or ref $value) {
    return E $path, _expected(string => $value);
  }
  if (B::svref_2object(\$value)->FLAGS & (B::SVp_IOK | B::SVp_NOK) and 0 + $value eq $value and $value * 0 == 0) {
    return E $path, "Expected string - got number." unless $self->coerce;
    $_[1] = "$value";    # coerce input value
  }
  if ($schema->{format}) {
    push @errors, $self->_validate_format($value, $path, $schema);
  }
  if (defined $schema->{maxLength}) {
    if (length($value) > $schema->{maxLength}) {
      push @errors, E $path, sprintf "String is too long: %s/%s.", length($value), $schema->{maxLength};
    }
  }
  if (defined $schema->{minLength}) {
    if (length($value) < $schema->{minLength}) {
      push @errors, E $path, sprintf "String is too short: %s/%s.", length($value), $schema->{minLength};
    }
  }
  if (defined $schema->{pattern}) {
    my $p = $schema->{pattern};
    unless ($value =~ /$p/) {
      push @errors, E $path, "String does not match '$p'";
    }
  }

  return @errors;
}

# FUNCTIONS ==================================================================

sub _cmp {
  return undef if !defined $_[0] or !defined $_[1];
  return "$_[3]=" if $_[2] and $_[0] >= $_[1];
  return $_[3] if $_[0] > $_[1];
  return "";
}

sub _expected {
  my $type = _guess_data_type($_[1]);
  return "Expected $_[0] - got different $type." if $_[0] =~ /\b$type\b/;
  return "Expected $_[0] - got $type.";
}

sub _guess_data_type {
  local $_ = $_[0];
  my $ref     = ref;
  my $blessed = Scalar::Util::blessed($_[0]);
  return 'object' if $ref eq 'HASH';
  return lc $ref if $ref and !$blessed;
  return 'null' if !defined;
  return 'boolean' if $blessed and "$_" eq "1" or "$_" eq "0";
  return 'number' if B::svref_2object(\$_)->FLAGS & (B::SVp_IOK | B::SVp_NOK) and 0 + $_ eq $_ and $_ * 0 == 0;
  return $blessed || 'string';
}

sub _guess_schema_type {
  return _guessed_right($_[1], 'object') if $_[0]->{additionalProperties};
  return _guessed_right($_[1], 'object') if $_[0]->{patternProperties};
  return _guessed_right($_[1], 'object') if $_[0]->{properties};
  return _guessed_right($_[1], 'object') if defined $_[0]->{maxProperties} or defined $_[0]->{minProperties};
  return _guessed_right($_[1], 'array')  if $_[0]->{additionalItems};
  return _guessed_right($_[1], 'array')  if $_[0]->{items};
  return _guessed_right($_[1], 'array')  if $_[0]->{uniqueItems};
  return _guessed_right($_[1], 'array')  if defined $_[0]->{maxItems} or defined $_[0]->{minItems};
  return _guessed_right($_[1], 'string') if $_[0]->{pattern};
  return _guessed_right($_[1], 'string') if defined $_[0]->{maxLength} or defined $_[0]->{minLength};
  return _guessed_right($_[1], 'number') if $_[0]->{multipleOf};
  return _guessed_right($_[1], 'number') if defined $_[0]->{maximum} or defined $_[0]->{minimum};
  return 'enum' if $_[0]->{enum};
  return undef;
}

sub _guessed_right {
  return _guess_data_type($_[0]) eq $_[1] ? $_[1] : undef;
}

sub _is_byte_string { $_[0] =~ /^[A-Za-z0-9\+\/\=]+$/; }
sub _is_date        { $_[0] =~ qr/^(\d+)-(\d+)-(\d+)$/io; }
sub _is_date_time   { $_[0] =~ qr/^(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+(?:\.\d+)?)(?:Z|([+-])(\d+):(\d+))?$/io; }
sub _is_domain      { warn "Data::Validate::Domain is not installed"; return; }

sub _is_email {
  state $email_rfc5322_re = do {
    my $atom           = qr;[a-zA-Z0-9_!#\$\%&'*+/=?\^`{}~|\-]+;o;
    my $quoted_string  = qr/"(?:\\[^\r\n]|[^\\"])*"/o;
    my $domain_literal = qr/\[(?:\\[\x01-\x09\x0B-\x0c\x0e-\x7f]|[\x21-\x5a\x5e-\x7e])*\]/o;
    my $dot_atom       = qr/$atom(?:[.]$atom)*/o;
    my $local_part     = qr/(?:$dot_atom|$quoted_string)/o;
    my $domain         = qr/(?:$dot_atom|$domain_literal)/o;

    qr/$local_part\@$domain/o;
  };

  return $_[0] =~ $email_rfc5322_re;
}

sub _is_ipv4 {
  my (@octets) = $_[0] =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
  return 4 == grep { $_ >= 0 && $_ <= 255 && $_ !~ /^0\d{1,2}$/ } @octets;
}

sub _is_ipv6 { warn "Data::Validate::IP is not installed"; return; }

sub _is_number {
  return unless $_[0] =~ /^-?\d+(\.\d+)?$/;
  return $_[0] eq unpack $_[1], pack $_[1], $_[0];
}

sub _is_true {
  return $_[0] if ref $_[0] and !Scalar::Util::blessed($_[0]);
  return 0 if !$_[0] or $_[0] =~ /^(n|false|off)/i;
  return 1;
}

sub _is_uri { $_[0] =~ qr!^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?!o; }

# Please report if you need to manually monkey patch this function
# https://github.com/jhthorsen/json-validator/issues
sub _load_yaml {
  my @YAML_MODULES = qw( YAML::XS YAML::Syck YAML::Tiny YAML );        # subject to change
  my $YAML_MODULE = (grep { eval "require $_;1" } @YAML_MODULES)[0];
  die "Need to install a YAML module: @YAML_MODULES" unless $YAML_MODULE;
  Mojo::Util::monkey_patch(__PACKAGE__, _load_yaml => eval "\\\&$YAML_MODULE\::Load");
  _load_yaml(@_);
}

sub _path {
  local $_ = $_[1];
  s!~!~0!g;
  s!/!~1!g;
  "$_[0]/$_";
}

package    # hide from
  JSON::Validator::Error;

use overload q("") => sub { sprintf '%s: %s', @{$_[0]}{qw( path message )} }, bool => sub {1}, fallback => 1;
sub message { shift->{message} }
sub path    { shift->{path} }
sub TO_JSON { {message => $_[0]->{message}, path => $_[0]->{path}} }

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014-2015, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
