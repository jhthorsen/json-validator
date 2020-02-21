package JSON::Validator;
use Mojo::Base -base;

use B;
use Carp 'confess';
use Exporter 'import';
use JSON::Validator::Error;
use JSON::Validator::Formats;
use JSON::Validator::Joi;
use JSON::Validator::Ref;
use JSON::Validator::Util
  qw(E data_checksum data_section data_type is_type json_pointer prefix_errors schema_type);
use List::Util 'uniq';
use Mojo::File 'path';
use Mojo::JSON::Pointer;
use Mojo::JSON qw(false true);
use Mojo::URL;
use Mojo::Util qw(url_unescape sha1_sum);
use Scalar::Util qw(blessed refaddr);

use constant CASE_TOLERANT     => File::Spec->case_tolerant;
use constant DEBUG             => $ENV{JSON_VALIDATOR_DEBUG} || 0;
use constant RECURSION_LIMIT   => $ENV{JSON_VALIDATOR_RECURSION_LIMIT} || 100;
use constant SPECIFICATION_URL => 'http://json-schema.org/draft-04/schema#';
use constant YAML_SUPPORT      => eval 'use YAML::XS 0.67;1';

our $VERSION   = '3.23';
our @EXPORT_OK = qw(joi validate_json);

my $BUNDLED_CACHE_DIR = path(path(__FILE__)->dirname, qw(Validator cache));
my $HTTP_SCHEME_RE    = qr{^https?:};

has cache_paths => sub {
  return [split(/:/, $ENV{JSON_VALIDATOR_CACHE_PATH} || ''),
    $BUNDLED_CACHE_DIR];
};

has formats => sub { shift->_build_formats };

has generate_definitions_path => sub {
  my $self = shift;
  Scalar::Util::weaken($self);
  return sub { [$self->{definitions_key} || 'definitions'] };
};

has version => 4;

has ua => sub {
  require Mojo::UserAgent;
  my $ua = Mojo::UserAgent->new;
  $ua->proxy->detect;
  $ua->max_redirects(3);
  $ua;
};

sub bundle {
  my ($self, $args) = @_;
  my ($cloner);

  my $schema
    = $args->{schema} ? $self->_resolve($args->{schema}) : $self->schema->data;
  my @topics = ([$schema, my $bundle = {}, '']);    # ([$from, $to], ...);

  if ($args->{replace}) {
    $cloner = sub {
      my $from      = shift;
      my $from_type = ref $from;
      my $tied;
      $from = $tied->schema if $from_type eq 'HASH' and $tied = tied %$from;
      my $to = $from_type eq 'ARRAY' ? [] : $from_type eq 'HASH' ? {} : $from;
      push @topics, [$from, $to] if $from_type;
      return $to;
    };
  }
  else {
    $cloner = sub {
      my $from      = shift;
      my $from_type = ref $from;

      my $tied = $from_type eq 'HASH' && tied %$from;
      unless ($tied) {
        my $to = $from_type eq 'ARRAY' ? [] : $from_type eq 'HASH' ? {} : $from;
        push @topics, [$from, $to] if $from_type;
        return $to;
      }

      return $from
        if !$args->{schema}
        and $tied->fqn =~ m!^\Q$self->{root_schema_url}\E\#!;

      my $path = $self->_definitions_path($bundle, $tied);
      unless ($self->{bundled_refs}{$tied->fqn}++) {
        push @topics,
          [_node($schema, $path, 1, 0) || {}, _node($bundle, $path, 1, 1)];
        push @topics, [$tied->schema, _node($bundle, $path, 0, 1)];
      }

      $path = join '/', '#', @$path;
      tie my %ref, 'JSON::Validator::Ref', $tied->schema, $path;
      return \%ref;
    };
  }

  Mojo::Util::deprecated('bundle({ref_key => "..."}) will be removed.')
    if $args->{ref_key};
  local $self->{definitions_key} = $args->{ref_key};
  local $self->{bundled_refs}    = {};

  while (@topics) {
    my ($from, $to) = @{shift @topics};
    if (ref $from eq 'ARRAY') {
      for (my $i = 0; $i < @$from; $i++) {
        $to->[$i] = $cloner->($from->[$i]);
      }
    }
    elsif (ref $from eq 'HASH') {
      for my $key (keys %$from) {
        $to->{$key} //= $cloner->($from->{$key});
      }
    }
  }

  return $bundle;
}

sub coerce {
  my $self = shift;
  return $self->{coerce} ||= {} unless defined(my $what = shift);

  if ($what eq '1') {
    Mojo::Util::deprecated('coerce(1) will be deprecated.');
    $what = {booleans => 1, numbers => 1, strings => 1};
  }

  state $short = {bool => 'booleans', def => 'defaults', num => 'numbers',
    str => 'strings'};

  $what = {map { ($_ => 1) } split /,/, $what} unless ref $what;
  $self->{coerce} = {};
  $self->{coerce}{($short->{$_} || $_)} = $what->{$_} for keys %$what;

  return $self;
}

sub get { JSON::Validator::Util::schema_extract(shift->schema->data, shift) }

sub joi {
  return JSON::Validator::Joi->new unless @_;
  my ($data, $joi) = @_;
  return $joi->validate($data, $joi);
}

sub load_and_validate_schema {
  my ($self, $spec, $args) = @_;
  my $schema = $args->{schema} || SPECIFICATION_URL;
  $self->version($1) if !$self->{version} and $schema =~ /draft-0+(\w+)/;
  $spec = $self->_resolve($spec);
  my @errors = $self->new(%$self)->schema($schema)->validate($spec);
  confess join "\n", "Invalid JSON specification $spec:", map {"- $_"} @errors
    if @errors;
  $self->{schema} = Mojo::JSON::Pointer->new($spec);
  $self;
}

sub new {
  my $self = shift->SUPER::new(@_);
  $self->coerce($self->{coerce}) if defined $self->{coerce};
  return $self;
}

sub schema {
  my $self = shift;
  return $self->{schema} unless @_;
  $self->{schema} = Mojo::JSON::Pointer->new($self->_resolve(shift));
  return $self;
}

sub singleton { state $jv = shift->new }

sub validate {
  my ($self, $data, $schema) = @_;
  $schema ||= $self->schema->data;
  return E '/', 'No validation rules defined.' unless defined $schema;

  local $self->{schema} = Mojo::JSON::Pointer->new($schema);
  local $self->{seen}   = {};
  local $self->{temp_schema} = [];    # make sure random-errors.t does not fail
  my @errors = $self->_validate($_[1], '', $schema);
  return @errors;
}

sub validate_json {
  __PACKAGE__->singleton->schema($_[1])->validate($_[0]);
}

sub _build_formats {
  return {
    'date'          => JSON::Validator::Formats->can('check_date'),
    'date-time'     => JSON::Validator::Formats->can('check_date_time'),
    'email'         => JSON::Validator::Formats->can('check_email'),
    'hostname'      => JSON::Validator::Formats->can('check_hostname'),
    'idn-email'     => JSON::Validator::Formats->can('check_idn_email'),
    'idn-hostname'  => JSON::Validator::Formats->can('check_idn_hostname'),
    'ipv4'          => JSON::Validator::Formats->can('check_ipv4'),
    'ipv6'          => JSON::Validator::Formats->can('check_ipv6'),
    'iri'           => JSON::Validator::Formats->can('check_iri'),
    'iri-reference' => JSON::Validator::Formats->can('check_iri_reference'),
    'json-pointer'  => JSON::Validator::Formats->can('check_json_pointer'),
    'regex'         => JSON::Validator::Formats->can('check_regex'),
    'relative-json-pointer' =>
      JSON::Validator::Formats->can('check_relative_json_pointer'),
    'time'          => JSON::Validator::Formats->can('check_time'),
    'uri'           => JSON::Validator::Formats->can('check_uri'),
    'uri-reference' => JSON::Validator::Formats->can('check_uri_reference'),
    'uri-reference' => JSON::Validator::Formats->can('check_uri_reference'),
    'uri-template'  => JSON::Validator::Formats->can('check_uri_template'),
  };
}

sub _definitions_path {
  my ($self, $bundle, $ref) = @_;
  my $path = $self->generate_definitions_path->($ref);

  # No need to rewrite, if it already has a nice name
  my $node   = _node($bundle, $path, 2, 0);
  my $prefix = join '/', @$path;
  if ($ref->fqn =~ m!#/$prefix/([^/]+)$!) {
    my $key = $1;

    if ( $self->{bundled_refs}{$ref->fqn}
      or !$node
      or !$node->{$key}
      or data_checksum($ref->schema) eq data_checksum($node->{$key}))
    {
      return [@$path, $key];
    }
  }

  # Generate definitions key based on filename
  my ($spec_path, $fragment) = split '#', $ref->fqn;
  my $key = $fragment;
  if (-e $spec_path) {
    $key = join '-', map { s!^\W+!!; $_ } grep {$_} path($spec_path)->basename,
      $fragment, substr(sha1_sum($spec_path), 0, 10);
  }

  # Fallback or nicer path name
  $key =~ s![^\w-]!_!g;
  return [@$path, $key];
}

# Try not to break JSON::Validator::OpenAPI::Mojolicious
sub _get { shift; JSON::Validator::Util::_schema_extract(@_) }

sub _id_key { $_[0]->version < 7 ? 'id' : '$id' }

sub _load_schema {
  my ($self, $url) = @_;

  if ($url =~ m!^https?://!) {
    warn "[JSON::Validator] Loading schema from URL $url\n" if DEBUG;
    return $self->_load_schema_from_url(Mojo::URL->new($url)->fragment(undef)),
      "$url";
  }

  if ($url =~ m!^data://([^/]*)/(.*)!) {
    my ($class, $file) = ($1, $2);
    my $text = data_section $class, $file, {confess => 1, encoding => 'UTF-8'};
    return $self->_load_schema_from_text(\$text), "$url";
  }

  if ($url =~ m!^\s*[\[\{]!) {
    warn "[JSON::Validator] Loading schema from string.\n" if DEBUG;
    return $self->_load_schema_from_text(\$url), '';
  }

  my $file = $url;
  $file =~ s!^file://!!;
  $file =~ s!#$!!;
  $file = path(split '/', $file);
  if (-e $file) {
    $file = $file->realpath;
    warn "[JSON::Validator] Loading schema from file: $file\n" if DEBUG;
    return $self->_load_schema_from_text(\$file->slurp),
      CASE_TOLERANT ? path(lc $file) : $file;
  }
  elsif ($url =~ m!^/! and $self->ua->server->app) {
    warn "[JSON::Validator] Loading schema from URL $url\n" if DEBUG;
    return $self->_load_schema_from_url(Mojo::URL->new($url)->fragment(undef)),
      "$url";
  }

  confess "Unable to load schema '$url' ($file)";
}

sub _load_schema_from_text {
  my ($self, $text) = @_;

  # JSON
  return Mojo::JSON::decode_json($$text) if $$text =~ /^\s*\{/s;

  # YAML
  die "[JSON::Validator] YAML::XS 0.67 is missing or could not be loaded."
    unless YAML_SUPPORT;

  no warnings 'once';
  local $YAML::XS::Boolean = 'JSON::PP';
  return YAML::XS::Load($$text);
}

sub _load_schema_from_url {
  my ($self, $url) = @_;
  my $cache_path = $self->cache_paths->[0];
  my $cache_file = Mojo::Util::md5_sum("$url");

  for (@{$self->cache_paths}) {
    my $path = path $_, $cache_file;
    warn "[JSON::Validator] Looking for cached spec $path ($url)\n" if DEBUG;
    next unless -r $path;
    return $self->_load_schema_from_text(\$path->slurp);
  }

  my $tx  = $self->ua->get($url);
  my $err = $tx->error && $tx->error->{message};
  confess "GET $url == $err"               if DEBUG and $err;
  die "[JSON::Validator] GET $url == $err" if $err;

  if ($cache_path
    and
    ($cache_path ne $BUNDLED_CACHE_DIR or $ENV{JSON_VALIDATOR_CACHE_ANYWAYS})
    and -w $cache_path)
  {
    $cache_file = path $cache_path, $cache_file;
    warn "[JSON::Validator] Caching $url to $cache_file\n"
      unless $ENV{HARNESS_ACTIVE};
    $cache_file->spurt($tx->res->body);
  }

  return $self->_load_schema_from_text(\$tx->res->body);
}

sub _node {
  my ($node, $path, $offset, $create) = @_;

  my $n = 0;
  while ($path->[$n]) {
    $node->{$path->[$n]} ||= {} if $create;
    return undef unless $node = $node->{$path->[$n]};
    last if (++$n) + $offset >= @$path;
  }

  return $node;
}

sub _ref_to_schema {
  my ($self, $schema) = @_;

  my @guard;
  while (my $tied = tied %$schema) {
    push @guard, $tied->ref;
    confess "Seems like you have a circular reference: @guard"
      if @guard > RECURSION_LIMIT;
    $schema = $tied->schema;
    last if is_type $schema, 'BOOL';
  }

  return $schema;
}

sub _register_schema {
  my ($self, $schema, $fqn) = @_;
  $fqn =~ s!(.)#$!$1!;
  $self->{schemas}{$fqn} = $schema;
}

# _resolve() method is used to convert all "id" into absolute URLs and
# resolve all the $ref's that we find inside JSON Schema specification.
sub _resolve {
  my ($self, $schema) = @_;
  my $id_key = $self->_id_key;
  my ($id, $resolved);

  local $self->{level} = $self->{level} || 0;
  delete $_[0]->{schemas}{''} unless $self->{level};

  if (ref $schema eq 'HASH') {
    $id = $schema->{$id_key} // '';
    return $resolved if $resolved = $self->{schemas}{$id};
  }
  elsif ($resolved = $self->{schemas}{$schema // ''}) {
    return $resolved;
  }
  elsif (is_type $schema, 'BOOL') {
    $self->_register_schema($schema, $schema);
    return $schema;
  }
  else {
    ($schema, $id) = $self->_load_schema($schema);
    $id = $schema->{$id_key} if $schema->{$id_key};
  }

  unless ($self->{level}) {
    my $rid = $schema->{$id_key} // $id;
    if ($rid) {
      confess "Root schema cannot have a fragment in the 'id'. ($rid)"
        if $rid =~ /\#./;
      confess "Root schema cannot have a relative 'id'. ($rid)"
        unless $rid =~ /^\w+:/
        or -e $rid
        or $rid =~ m!^/!;
    }
    warn sprintf "[JSON::Validator] Using root_schema_url of '$rid'\n" if DEBUG;
    $self->{root_schema_url} = $rid;
  }

  $self->{level}++;
  $self->_register_schema($schema, $id);

  my (%seen, @refs);
  my @topics
    = ([$schema, is_type($id, 'Mojo::File') ? $id : Mojo::URL->new($id)]);
  while (@topics) {
    my ($topic, $base) = @{shift @topics};

    if (is_type $topic, 'ARRAY') {
      push @topics, map { [$_, $base] } @$topic;
    }
    elsif (is_type $topic, 'HASH') {
      my $seen_addr = join ':', $base, refaddr($topic);
      next if $seen{$seen_addr}++;

      push @refs, [$topic, $base] and next
        if $topic->{'$ref'} and !ref $topic->{'$ref'};

      if ($topic->{$id_key} and !ref $topic->{$id_key}) {
        my $fqn = Mojo::URL->new($topic->{$id_key});
        $fqn = $fqn->to_abs($base) unless $fqn->is_abs;
        $self->_register_schema($topic, $fqn->to_string);
      }

      push @topics, map { [$_, $base] } values %$topic;
    }
  }

  # Need to register "id":"..." before resolving "$ref":"..."
  $self->_resolve_ref(@$_) for @refs;

  return $schema;
}

sub _location_to_abs {
  my ($location, $base) = @_;
  my $location_as_url = Mojo::URL->new($location);
  return $location_as_url if $location_as_url->is_abs;

  # definitely relative now
  if (is_type $base, 'Mojo::File') {
    return $base if !length $location;
    my $path = $base->sibling(split '/', $location)->realpath;
    return CASE_TOLERANT ? lc($path) : $path;
  }
  return $location_as_url->to_abs($base);
}

sub _resolve_ref {
  my ($self, $topic, $url) = @_;
  return if tied %$topic;

  my $other = $topic;
  my ($fqn, $ref, @guard);

  while (1) {
    last if is_type $other, 'BOOL';
    $ref = $other->{'$ref'};
    push @guard, $other->{'$ref'};
    confess "Seems like you have a circular reference: @guard"
      if @guard > RECURSION_LIMIT;
    last if !$ref or ref $ref;
    $fqn = $ref =~ m!^/! ? "#$ref" : $ref;
    my ($location, $pointer) = split /#/, $fqn, 2;
    $url     = $location = _location_to_abs($location, $url);
    $pointer = undef if length $location and !length $pointer;
    $pointer = url_unescape $pointer if defined $pointer;
    $fqn     = join '#', grep defined, $location, $pointer;
    $other   = $self->_resolve($location);

    if (defined $pointer and length $pointer and $pointer =~ m!^/!) {
      $other = Mojo::JSON::Pointer->new($other)->get($pointer);
      confess
        qq[Possibly a typo in schema? Could not find "$pointer" in "$location" ($ref)]
        if not defined $other;
    }
  }

  tie %$topic, 'JSON::Validator::Ref', $other, $topic->{'$ref'}, $fqn;
}

sub _validate {
  my ($self, $data, $path, $schema) = @_;

  $schema = $self->_ref_to_schema($schema)
    if ref $schema eq 'HASH' and $schema->{'$ref'};
  return $schema ? () : E $path, [not => 'not'] if is_type $schema, 'BOOL';

  my $seen_addr = join ':', refaddr($schema),
    (ref $data ? refaddr $data : ++$self->{seen}{scalar});

  # Avoid recursion
  if ($self->{seen}{$seen_addr}) {
    return @{$self->{seen}{$seen_addr}};
  }

  $self->{seen}{$seen_addr} = \my @errors;
  my $to_json
    = (blessed $data and $data->can('TO_JSON')) ? \$data->TO_JSON : undef;
  $data = $$to_json if $to_json;
  my $type = $schema->{type} || schema_type $schema, $data;

  # Test base schema before allOf, anyOf or oneOf
  if (ref $type eq 'ARRAY') {
    push @{$self->{temp_schema}}, [map { +{%$schema, type => $_} } @$type];
    return $self->_validate_any_of_types($to_json ? $$to_json : $_[1],
      $path, $self->{temp_schema}[-1]);
  }
  elsif ($type) {
    my $method = sprintf '_validate_type_%s', $type;
    @errors = $self->$method($to_json ? $$to_json : $_[1], $path, $schema);
    return @errors if @errors;
  }

  if (exists $schema->{const}) {
    push @errors,
      $self->_validate_type_const($to_json ? $$to_json : $_[1], $path, $schema);
    return @errors if @errors;
  }

  if ($schema->{enum}) {
    push @errors,
      $self->_validate_type_enum($to_json ? $$to_json : $_[1], $path, $schema);
    return @errors if @errors;
  }

  if (my $rules = $schema->{not}) {
    push @errors, $self->_validate($to_json ? $$to_json : $_[1], $path, $rules);
    return @errors ? () : (E $path, [not => 'not']);
  }

  if (my $rules = $schema->{allOf}) {
    push @errors,
      $self->_validate_all_of($to_json ? $$to_json : $_[1], $path, $rules);
  }

  if (my $rules = $schema->{anyOf}) {
    push @errors,
      $self->_validate_any_of($to_json ? $$to_json : $_[1], $path, $rules);
  }

  if (my $rules = $schema->{oneOf}) {
    push @errors,
      $self->_validate_one_of($to_json ? $$to_json : $_[1], $path, $rules);
  }

  if ($schema->{if}) {
    my $rules
      = $self->_validate($data, $path, $schema->{if})
      ? $schema->{else}
      : $schema->{then};
    push @errors, $self->_validate($data, $path, $rules // {});
  }

  return @errors;
}

sub _validate_all_of {
  my ($self, $data, $path, $rules) = @_;
  my @errors;

  my $i = 0;
  for my $rule (@$rules) {
    next unless my @e = $self->_validate($_[1], $path, $rule);
    push @errors, [$i, @e];
  }
  continue {
    $i++;
  }

  return if not @errors;

  my @details = map { my ($i, @e) = @$_; map $_->details, @e } @errors;

  return prefix_errors(allOf => @errors)
    if @details == 1
    or grep $_->[1] ne 'type', @details;

  # combine all 'type' errors together
  my $want_types = join '/', uniq map $_->[0], @details;
  return E $path, [allOf => type => $want_types, $details[-1][2]];
}

sub _validate_any_of_types {
  my ($self, $data, $path, $rules) = @_;
  my @errors;

  for my $rule (@$rules) {
    return unless my @e = $self->_validate($_[1], $path, $rule);
    push @errors, @e;
  }

 # disregard any 'type' errors in favour of a more specific error, when possible
  if (my @e = grep $_->details->[1] ne 'type', @errors) {
    return @e;
  }

  # combine all 'type' errors together
  my @details    = map $_->details, @errors;
  my $want_types = join '/', uniq map $_->[0], @details;
  return E $path, [$want_types => 'type', $details[-1][2]];
}

sub _validate_any_of {
  my ($self, $data, $path, $rules) = @_;
  my @errors;

  my $i = 0;
  for my $rule (@$rules) {
    return unless my @e = $self->_validate($_[1], $path, $rule);
    push @errors, [$i, @e];
  }
  continue {
    $i++;
  }

  my @details = map { my ($i, @e) = @$_; map $_->details, @e } @errors;

  return prefix_errors(anyOf => @errors)
    if @details == 1
    or grep $_->[1] ne 'type', @details;

  # combine all 'type' errors together
  my $want_types = join '/', uniq map $_->[0], @details;
  return E $path, [anyOf => type => $want_types, $details[-1][2]];
}

sub _validate_one_of {
  my ($self, $data, $path, $rules) = @_;
  my @errors;

  my ($i, @passed) = (0);
  for my $rule (@$rules) {
    my @e = $self->_validate($_[1], $path, $rule) or push @passed, $i and next;
    push @errors, [$i, @e];
  }
  continue {
    $i++;
  }

  return if @passed == 1;
  return E $path, [oneOf => 'all_rules_match'] unless @errors;
  return E $path, [oneOf => 'n_rules_match', join(', ', @passed)] if @passed;

  my @details = map { my ($i, @e) = @$_; map $_->details, @e } @errors;

  return prefix_errors(oneOf => @errors)
    if @details == 1
    or grep $_->[1] ne 'type', @details;

  # combine all 'type' errors together
  my $want_types = join '/', uniq map $_->[0], @details;
  return E $path, [oneOf => type => $want_types, $details[-1][2]];
}

sub _validate_number_max {
  my ($self, $value, $path, $schema, $expected) = @_;
  my @errors;

  my $cmp_with = $schema->{exclusiveMaximum} // '';
  if (is_type $cmp_with, 'BOOL') {
    push @errors, E $path,
      [$expected => ex_maximum => $value, $schema->{maximum}]
      unless $value < $schema->{maximum};
  }
  elsif (is_type $cmp_with, 'NUM') {
    push @errors, E $path, [$expected => ex_maximum => $value, $cmp_with]
      unless $value < $cmp_with;
  }

  if (exists $schema->{maximum}) {
    my $cmp_with = $schema->{maximum};
    push @errors, E $path, [$expected => maximum => $value, $cmp_with]
      unless $value <= $cmp_with;
  }

  return @errors;
}

sub _validate_number_min {
  my ($self, $value, $path, $schema, $expected) = @_;
  my @errors;

  my $cmp_with = $schema->{exclusiveMinimum} // '';
  if (is_type $cmp_with, 'BOOL') {
    push @errors, E $path,
      [$expected => ex_minimum => $value, $schema->{minimum}]
      unless $value > $schema->{minimum};
  }
  elsif (is_type $cmp_with, 'NUM') {
    push @errors, E $path, [$expected => ex_minimum => $value, $cmp_with]
      unless $value > $cmp_with;
  }

  if (exists $schema->{minimum}) {
    my $cmp_with = $schema->{minimum};
    push @errors, E $path, [$expected => minimum => $value, $cmp_with]
      unless $value >= $cmp_with;
  }

  return @errors;
}

sub _validate_type_enum {
  my ($self, $data, $path, $schema) = @_;
  my $enum = $schema->{enum};
  my $m    = data_checksum $data;

  for my $i (@$enum) {
    return if $m eq data_checksum $i;
  }

  $enum = join ', ',
    map { (!defined or ref) ? Mojo::JSON::encode_json($_) : $_ } @$enum;
  return E $path, [enum => enum => $enum];
}

sub _validate_type_const {
  my ($self, $data, $path, $schema) = @_;
  my $const = $schema->{const};

  return if data_checksum($data) eq data_checksum($const);
  return E $path, [const => const => Mojo::JSON::encode_json($const)];
}

sub _validate_format {
  my ($self, $value, $path, $schema) = @_;
  my $code = $self->formats->{$schema->{format}};
  return do { warn "Format rule for '$schema->{format}' is missing"; return }
    unless $code;
  return unless my $err = $code->($value);
  return E $path, [format => $schema->{format}, $err];
}

sub _validate_type_any { }

sub _validate_type_array {
  my ($self, $data, $path, $schema) = @_;
  my @errors;

  if (ref $data ne 'ARRAY') {
    return E $path, [array => type => data_type $data];
  }
  if (defined $schema->{minItems} and $schema->{minItems} > @$data) {
    push @errors, E $path,
      [array => minItems => int(@$data), $schema->{minItems}];
  }
  if (defined $schema->{maxItems} and $schema->{maxItems} < @$data) {
    push @errors, E $path,
      [array => maxItems => int(@$data), $schema->{maxItems}];
  }
  if ($schema->{uniqueItems}) {
    my %uniq;
    for (@$data) {
      next if !$uniq{data_checksum($_)}++;
      push @errors, E $path, [array => 'uniqueItems'];
      last;
    }
  }

  if ($schema->{contains}) {
    my @e;
    for my $i (0 .. @$data - 1) {
      my @tmp = $self->_validate($data->[$i], "$path/$i", $schema->{contains});
      push @e, \@tmp if @tmp;
    }
    push @errors, map {@$_} @e if @e >= @$data;
  }
  elsif (ref $schema->{items} eq 'ARRAY') {
    my $additional_items = $schema->{additionalItems} // {type => 'any'};
    my @rules            = @{$schema->{items}};

    if ($additional_items) {
      push @rules, $additional_items while @rules < @$data;
    }

    if (@rules == @$data) {
      for my $i (0 .. @rules - 1) {
        push @errors, $self->_validate($data->[$i], "$path/$i", $rules[$i]);
      }
    }
    elsif (!$additional_items) {
      push @errors, E $path,
        [array => additionalItems => int(@$data), int(@rules)];
    }
  }
  elsif (exists $schema->{items}) {
    for my $i (0 .. @$data - 1) {
      push @errors, $self->_validate($data->[$i], "$path/$i", $schema->{items});
    }
  }

  return @errors;
}

sub _validate_type_boolean {
  my ($self, $value, $path, $schema) = @_;
  return if is_type $value, 'BOOL';

  # String that looks like a boolean
  if (
        defined $value
    and $self->{coerce}{booleans}
    and (B::svref_2object(\$value)->FLAGS & (B::SVp_IOK | B::SVp_NOK)
      or $value =~ /^(true|false)$/)
    )
  {
    $_[1] = $value ? true : false;
    return;
  }

  return E $path, [boolean => type => data_type $value];
}

sub _validate_type_integer {
  my ($self, $value, $path, $schema) = @_;
  my @errors = $self->_validate_type_number($_[1], $path, $schema, 'integer');

  return @errors if @errors;
  return         if $value =~ /^-?\d+$/;
  return E $path, [integer => type => data_type $value];
}

sub _validate_type_null {
  my ($self, $value, $path, $schema) = @_;

  return unless defined $value;
  return E $path, ['null', 'null'];
}

sub _validate_type_number {
  my ($self, $value, $path, $schema, $expected) = @_;
  my @errors;

  $expected ||= 'number';

  if (!defined $value or ref $value) {
    return E $path, [$expected => type => data_type $value];
  }
  unless (is_type $value, 'NUM') {
    return E $path, [$expected => type => data_type $value]
      if !$self->{coerce}{numbers}
      or $value !~ /^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?$/;
    $_[1] = 0 + $value;    # coerce input value
  }

  push @errors, $self->_validate_format($value, $path, $schema)
    if $schema->{format};
  push @errors, $self->_validate_number_max($value, $path, $schema, $expected);
  push @errors, $self->_validate_number_min($value, $path, $schema, $expected);

  my $d = $schema->{multipleOf};
  push @errors, E $path, [$expected => multipleOf => $d]
    if $d and ($value / $d) =~ /\.[^0]+$/;

  return @errors;
}

sub _validate_type_object {
  my ($self, $data, $path, $schema) = @_;

  if (ref $data ne 'HASH') {
    return E $path, [object => type => data_type $data];
  }

  my @errors;
  my @dkeys = sort keys %$data;
  if (defined $schema->{maxProperties} and $schema->{maxProperties} < @dkeys) {
    push @errors, E $path,
      [object => maxProperties => int(@dkeys), $schema->{maxProperties}];
  }
  if (defined $schema->{minProperties} and $schema->{minProperties} > @dkeys) {
    push @errors, E $path,
      [object => minProperties => int(@dkeys), $schema->{minProperties}];
  }
  if (my $n_schema = $schema->{propertyNames}) {
    for my $name (keys %$data) {
      next unless my @e = $self->_validate($name, $path, $n_schema);
      push @errors, prefix_errors propertyName => [map { ($name, $_) } @e];
    }
  }

  my %rules;
  for my $k (keys %{$schema->{properties}}) {
    my $r = $schema->{properties}{$k};
    push @{$rules{$k}}, $r;
    if (  $self->{coerce}{defaults}
      and ref $r eq 'HASH'
      and exists $r->{default}
      and !exists $data->{$k})
    {
      $data->{$k} = $r->{default};
    }
  }

  for my $p (keys %{$schema->{patternProperties} || {}}) {
    my $r = $schema->{patternProperties}{$p};
    push @{$rules{$_}}, $r for sort grep { $_ =~ /$p/ } @dkeys;
  }

  my $additional
    = exists $schema->{additionalProperties}
    ? $schema->{additionalProperties}
    : {};
  if ($additional) {
    $additional = {} unless is_type $additional, 'HASH';
    $rules{$_} ||= [$additional] for @dkeys;
  }
  elsif (my @k = grep { !$rules{$_} } @dkeys) {
    local $" = ', ';
    return E $path, [object => additionalProperties => join '/', @k];
  }

  for my $k (sort { $a cmp $b } uniq @{$schema->{required} || []}) {
    next if exists $data->{$k};
    push @errors, E json_pointer($path, $k), [object => 'required'];
    delete $rules{$k};
  }

  my $dependencies = $schema->{dependencies} || {};
  for my $k (keys %$dependencies) {
    next if not exists $data->{$k};
    if (ref $dependencies->{$k} eq 'ARRAY') {
      push @errors,
        map { E json_pointer($path, $_), [object => dependencies => $k] }
        grep { !exists $data->{$_} } @{$dependencies->{$k}};
    }
    elsif (ref $dependencies->{$k} eq 'HASH') {
      push @errors,
        $self->_validate_type_object($data, $path, $schema->{dependencies}{$k});
    }
  }

  for my $k (sort keys %rules) {
    for my $r (@{$rules{$k}}) {
      next unless exists $data->{$k};
      $r = $self->_ref_to_schema($r) if ref $r eq 'HASH' and $r->{'$ref'};
      my @e = $self->_validate($data->{$k}, json_pointer($path, $k), $r);
      push @errors, @e;
      next if @e or !is_type $r, 'HASH';
      push @errors,
        $self->_validate_type_enum($data->{$k}, json_pointer($path, $k), $r)
        if $r->{enum};
      push @errors,
        $self->_validate_type_const($data->{$k}, json_pointer($path, $k), $r)
        if $r->{const};
    }
  }

  return @errors;
}

sub _validate_type_string {
  my ($self, $value, $path, $schema) = @_;
  my @errors;

  if (!defined $value or ref $value) {
    return E $path, [string => type => data_type $value];
  }
  if (  B::svref_2object(\$value)->FLAGS & (B::SVp_IOK | B::SVp_NOK)
    and 0 + $value eq $value
    and $value * 0 == 0)
  {
    return E $path, [string => type => data_type $value]
      unless $self->{coerce}{strings};
    $_[1] = "$value";    # coerce input value
  }
  if ($schema->{format}) {
    push @errors, $self->_validate_format($value, $path, $schema);
  }
  if (defined $schema->{maxLength}) {
    if (length($value) > $schema->{maxLength}) {
      push @errors, E $path,
        [string => maxLength => length($value), $schema->{maxLength}];
    }
  }
  if (defined $schema->{minLength}) {
    if (length($value) < $schema->{minLength}) {
      push @errors, E $path,
        [string => minLength => length($value), $schema->{minLength}];
    }
  }
  if (defined $schema->{pattern}) {
    my $p = $schema->{pattern};
    push @errors, E $path, [string => pattern => $p] unless $value =~ /$p/;
  }

  return @errors;
}

1;

=encoding utf8

=head1 NAME

JSON::Validator - Validate data against a JSON schema

=head1 SYNOPSIS

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

  # Use joi() to build the schema
  use JSON::Validator 'joi';

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
    });
  );

=head1 DESCRIPTION

L<JSON::Validator> is a data structure validation library based around
L<JSON Schema|https://json-schema.org/>. This module can be used directly with
a JSON schema or you can use the elegant DSL schema-builder
L<JSON::Validator::Joi> to define the schema programmatically.

=head2 Supported schema formats

L<JSON::Validator> can load JSON schemas in multiple formats: Plain perl data
structured (as shown in L</SYNOPSIS>), JSON or YAML. The JSON parsing is done
with L<Mojo::JSON>, while YAML files require the optional module L<YAML::XS> to
be installed.

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

=item * JSON schema, draft 4, 6, 7

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

=head1 ERROR OBJECT

The methods L</validate> and the function L</validate_json> returns a list of
L<JSON::Validator::Error> objects when the input data violates the L</schema>.

=head1 FUNCTIONS

=head2 joi

  use JSON::Validator "joi";
  my $joi    = joi;
  my @errors = joi($data, $joi); # same as $joi->validate($data);

Used to construct a new L<JSON::Validator::Joi> object or perform validation.

=head2 validate_json

  use JSON::Validator "validate_json";
  my @errors = validate_json $data, $schema;

This can be useful in web applications:

  my @errors = validate_json $c->req->json, "data://main/spec.json";

See also L</validate> and L</ERROR OBJECT> for more details.

=head1 ATTRIBUTES

=head2 cache_paths

  my $jv        = $jv->cache_paths(\@paths);
  my $array_ref = $jv->cache_paths;

A list of directories to where cached specifications are stored. Defaults to
C<JSON_VALIDATOR_CACHE_PATH> environment variable and the specs that is bundled
with this distribution.

C<JSON_VALIDATOR_CACHE_PATH> can be a list of directories, each separated by ":".

See L</Bundled specifications> for more details.

=head2 formats

  my $hash_ref  = $jv->formats;
  my $jv = $jv->formats(\%hash);

Holds a hash-ref, where the keys are supported JSON type "formats", and
the values holds a code block which can validate a given format. A code
block should return C<undef> on success and an error string on error:

  sub { return defined $_[0] && $_[0] eq "42" ? undef : "Not the answer." };

See L<JSON::Validator::Formats> for a list of supported formats.

=head2 generate_definitions_path

  my $cb = $jv->generate_definitions_path;
  my $jv = $jv->generate_definitions_path(sub { my $ref = shift; return ["definitions"] });

Holds a callback that is used by L</bundle> to figure out where to place
references. The default location is under "definitions", but this can be
changed to whatever you want. The input C<$ref> variable passed on is a
L<JSON::Validator::Ref> object.

This attribute is EXPERIMENTAL and might change without warning.

=head2 ua

  my $ua = $jv->ua;
  my $jv = $jv->ua(Mojo::UserAgent->new);

Holds a L<Mojo::UserAgent> object, used by L</schema> to load a JSON schema
from remote location.

The default L<Mojo::UserAgent> will detect proxy settings and have
L<Mojo::UserAgent/max_redirects> set to 3.

=head2 version

  my $int = $jv->version;
  my $jv  = $jv->version(7);

Used to set the JSON Schema version to use. Will be set automatically when
using L</load_and_validate_schema>, unless already set.

=head1 METHODS

=head2 bundle

  # These two lines does the same
  my $schema = $jv->bundle({schema => $jv->schema->data});
  my $schema = $jv->bundle;

  # Will only bundle a section of the schema
  my $schema = $jv->bundle({schema => $jv->schema->get("/properties/person/age")});

Used to create a new schema, where there are no "$ref" pointing to external
resources. This means that all the "$ref" that are found, will be moved into
the "definitions" key, in the returned C<$schema>.

=head2 coerce

  my $jv       = $jv->coerce('bool,def,num,str');
  my $jv       = $jv->coerce('booleans,defaults,numbers,strings');
  my $hash_ref = $jv->coerce;

Set the given type to coerce. Before enabling coercion this module is very
strict when it comes to validating types. Example: The string C<"1"> is not
the same as the number C<1>, unless you have "numbers" coercion enabled.

=over 2

=item * booleans

Will convert what looks can be interpreted as a boolean (that is, an actual
numeric C<1> or C<0>, and the strings "true" and "false") to a
L<JSON::PP::Boolean> object. Note that "foo" is not considered a true value and
will fail the validation.

=item * defaults

Will copy the default value defined in the schema, into the input structure,
if the input value is non-existing.

Note that support for "default" is currently EXPERIMENTAL, and enabling this
might be changed in future versions.

=item * numbers

Will convert strings that looks like numbers, into true numbers. This works for
both the "integer" and "number" types.

=item * strings

Will convert a number into a string. This works for the "string" type.

=back

=head2 get

  my $sub_schema = $jv->get("/x/y");
  my $sub_schema = $jv->get(["x", "y"]);

Extract value from L</schema> identified by the given JSON Pointer. Will at the
same time resolve C<$ref> if found. Example:

  $jv->schema({x => {'$ref' => '#/y'}, y => {'type' => 'string'}});
  $jv->schema->get('/x')           == {'$ref' => '#/y'}
  $jv->schema->get('/x')->{'$ref'} == '#/y'
  $jv->get('/x')                   == {type => 'string'}

The argument can also be an array-ref with the different parts of the pointer
as each elements.

=head2 new

  $jv = JSON::Validator->new(%attributes);
  $jv = JSON::Validator->new(\%attributes);

Creates a new L<JSON::Validate> object.

=head2 load_and_validate_schema

  my $jv = $jv->load_and_validate_schema($schema, \%args);

Will load and validate C<$schema> against the OpenAPI specification. C<$schema>
can be anything L<JSON::Validator/schema> accepts. The expanded specification
will be stored in L<JSON::Validator/schema> on success. See
L<JSON::Validator/schema> for the different version of C<$url> that can be
accepted.

C<%args> can be used to further instruct the validation process:

=over 2

=item * schema

Defaults to "http://json-schema.org/draft-04/schema#", but can be any
structured that can be used to validate C<$schema>.

=back

=head2 schema

  my $jv     = $jv->schema($json_or_yaml_string);
  my $jv     = $jv->schema($url);
  my $jv     = $jv->schema(\%schema);
  my $jv     = $jv->schema(JSON::Validator::Joi->new);
  my $schema = $jv->schema;

Used to set a schema from either a data structure or a URL.

C<$schema> will be a L<Mojo::JSON::Pointer> object when loaded,
and C<undef> by default.

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

=head2 singleton

  my $jv = JSON::Validator->singleton;

Returns the L<JSON::Validator> object used by L</validate_json>.

=head2 validate

  my @errors = $jv->validate($data);
  my @errors = $jv->validate($data, $schema);

Validates C<$data> against a given JSON L</schema>. C<@errors> will
contain validation error objects or be an empty list on success.

See L</ERROR OBJECT> for details.

C<$schema> is optional, but when specified, it will override schema stored in
L</schema>. Example:

  $jv->validate({hero => "superwoman"}, {type => "object"});

=head2 SEE ALSO

=over 2

=item * L<Mojolicious::Plugin::OpenAPI>

L<Mojolicious::Plugin::OpenAPI> is a plugin for L<Mojolicious> that utilize
L<JSON::Validator> and the L<OpenAPI specification|https://www.openapis.org/>
to build routes with input and output validation.

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014-2018, Jan Henning Thorsen

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
