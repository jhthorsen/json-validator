package JSON::Validator;
use Mojo::Base -base;
use Exporter 'import';

use Carp qw(confess);
use JSON::Validator::Formats;
use JSON::Validator::Ref;
use JSON::Validator::Store;
use JSON::Validator::Util qw(E data_checksum data_type is_type json_pointer prefix_errors schema_type);
use List::Util qw(uniq);
use Mojo::File qw(path);
use Mojo::JSON qw(false true);
use Mojo::URL;
use Mojo::Util qw(sha1_sum);
use Scalar::Util qw(blessed refaddr);

use constant RECURSION_LIMIT => $ENV{JSON_VALIDATOR_RECURSION_LIMIT} || 100;

our $VERSION   = '4.12';
our @EXPORT_OK = qw(joi validate_json);

our %SCHEMAS = (
  'http://json-schema.org/draft-04/schema#'             => '+Draft4',
  'http://json-schema.org/draft-06/schema#'             => '+Draft6',
  'http://json-schema.org/draft-07/schema#'             => '+Draft7',
  'https://json-schema.org/draft/2019-09/schema'        => '+Draft201909',
  'http://swagger.io/v2/schema.json'                    => '+OpenAPIv2',
  'https://spec.openapis.org/oas/3.0/schema/2019-04-02' => '+OpenAPIv3',
);

has formats                   => sub { shift->_build_formats };
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

sub version {
  my $self = shift;
  Mojo::Util::deprecated('version() will be removed in future version.');
  return $self->{version} || 4 unless @_;
  $self->{version} = shift;
  $self;
}

sub bundle {
  my ($self, $args) = @_;
  my $cloner;

  my $get_data  = $self->can('data') ? 'data' : 'schema';
  my $schema    = $self->_new_schema($args->{schema} || $self->$get_data);
  my $schema_id = $schema->id;
  my @topics    = ([$schema->data, my $bundle = {}]);                        # ([$from, $to], ...);

  if ($args->{replace}) {
    $cloner = sub {
      my $from      = shift;
      my $from_type = ref $from;
      my $tied      = $from_type eq 'HASH' && tied %$from;

      $from = $tied->schema if $tied;
      my $to = $from_type eq 'ARRAY' ? [] : $from_type eq 'HASH' ? {} : $from;
      push @topics, [$from, $to] if $from_type;
      return $to;
    };
  }
  else {
    $cloner = sub {
      my $from      = shift;
      my $from_type = ref $from;
      my $tied      = $from_type eq 'HASH' && tied %$from;

      unless ($tied) {
        my $to = $from_type eq 'ARRAY' ? [] : $from_type eq 'HASH' ? {} : $from;
        push @topics, [$from, $to] if $from_type;
        return $to;
      }

      # Traverse all $ref
      while (my $tmp = tied %{$tied->schema}) { $tied = $tmp }

      return $from if !$args->{schema} and $tied->fqn =~ m!^\Q$schema_id\E\#!;

      my $path = $self->_definitions_path($bundle, $tied);
      unless ($self->{bundled_refs}{$tied->fqn}++) {
        push @topics, [_node($schema->data, $path, 1, 0) || {}, _node($bundle, $path, 1, 1)];
        push @topics, [$tied->schema, _node($bundle, $path, 0, 1)];
      }

      $path = join '/', '#', @$path;
      tie my %ref, 'JSON::Validator::Ref', $tied->schema, $path;
      return \%ref;
    };
  }

  local $self->{bundled_refs} = {};

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

  state $short = {bool => 'booleans', def => 'defaults', num => 'numbers', str => 'strings'};

  $what                                 = {map { ($_ => 1) } split /,/, $what} unless ref $what;
  $self->{coerce}                       = {};
  $self->{coerce}{($short->{$_} || $_)} = $what->{$_} for keys %$what;

  return $self;
}

sub get { JSON::Validator::Util::schema_extract(shift->schema->data, shift) }

sub joi {
  Mojo::Util::deprecated('JSON::Validator::joi() is replaced by JSON::Validator::Joi::joi().');
  require JSON::Validator::Joi;
  return JSON::Validator::Joi->new unless @_;
  my ($data, $joi) = @_;
  return $joi->validate($data, $joi);
}

sub load_and_validate_schema {
  my ($self, $schema, $args) = @_;

  $self->{version} = $1 if !$self->{version} and ($args->{schema} || 'draft-04') =~ m!draft-0+(\w+)!;

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
  return $self->{schema} unless @_;
  $self->{schema} = $self->_new_schema(shift);
  return $self;
}

sub singleton {
  Mojo::Util::deprecated('singleton() will be removed in future version.');
  state $jv = shift->new;
}

sub validate {
  my ($self, $data, $schema) = @_;
  $schema //= $self->schema->data;
  return E '/', 'No validation rules defined.' unless defined $schema;

  local $self->{schema}      = $self->_new_schema($schema);
  local $self->{seen}        = {};
  local $self->{temp_schema} = [];                            # make sure random-errors.t does not fail
  my @errors = sort { $a->path cmp $b->path } $self->_validate($_[1], '', $schema);
  return @errors;
}

sub validate_json {
  Mojo::Util::deprecated('validate_json() will be removed in future version.');
  __PACKAGE__->singleton->schema($_[1])->validate($_[0]);
}

sub _build_formats {
  return {
    'byte'                  => JSON::Validator::Formats->can('check_byte'),
    'date'                  => JSON::Validator::Formats->can('check_date'),
    'date-time'             => JSON::Validator::Formats->can('check_date_time'),
    'duration'              => JSON::Validator::Formats->can('check_duration'),
    'double'                => JSON::Validator::Formats->can('check_double'),
    'email'                 => JSON::Validator::Formats->can('check_email'),
    'float'                 => JSON::Validator::Formats->can('check_float'),
    'hostname'              => JSON::Validator::Formats->can('check_hostname'),
    'idn-email'             => JSON::Validator::Formats->can('check_idn_email'),
    'idn-hostname'          => JSON::Validator::Formats->can('check_idn_hostname'),
    'int32'                 => JSON::Validator::Formats->can('check_int32'),
    'int64'                 => JSON::Validator::Formats->can('check_int64'),
    'ipv4'                  => JSON::Validator::Formats->can('check_ipv4'),
    'ipv6'                  => JSON::Validator::Formats->can('check_ipv6'),
    'iri'                   => JSON::Validator::Formats->can('check_iri'),
    'iri-reference'         => JSON::Validator::Formats->can('check_iri_reference'),
    'json-pointer'          => JSON::Validator::Formats->can('check_json_pointer'),
    'regex'                 => JSON::Validator::Formats->can('check_regex'),
    'relative-json-pointer' => JSON::Validator::Formats->can('check_relative_json_pointer'),
    'time'                  => JSON::Validator::Formats->can('check_time'),
    'uri'                   => JSON::Validator::Formats->can('check_uri'),
    'uri-reference'         => JSON::Validator::Formats->can('check_uri_reference'),
    'uri-reference'         => JSON::Validator::Formats->can('check_uri_reference'),
    'uri-template'          => JSON::Validator::Formats->can('check_uri_template'),
    'uuid'                  => JSON::Validator::Formats->can('check_uuid'),
  };
}

sub _definitions_path {
  my ($self, $bundle, $ref) = @_;
  my $path = $self->_definitions_path_for_ref($ref);

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
  my $fqn = Mojo::URL->new($ref->fqn);
  my $key = $fqn->fragment;
  if ($fqn->scheme and $fqn->scheme eq 'file') {
    $key = join '-', map { s!^\W+!!; $_ } grep {$_} path($fqn->path)->basename, $key,
      substr(sha1_sum($fqn->path), 0, 10);
  }

  # Fallback or nicer path name
  $key =~ s![^\w-]!_!g;
  return [@$path, $key];
}

sub _definitions_path_for_ref { ['definitions'] }

# Try not to break JSON::Validator::OpenAPI::Mojolicious
sub _get { shift; JSON::Validator::Util::_schema_extract(@_) }

sub _find_and_resolve_refs {
  my ($self, $base_url, $schema) = @_;
  my %root = is_type($schema, 'HASH') ? %$schema : ();

  my ($id_key, @topics, @refs, %seen) = ($self->_id_key, [$base_url, $schema]);
  while (@topics) {
    my ($base_url, $topic) = @{shift @topics};

    if (is_type $topic, 'ARRAY') {
      push @topics, map { [$base_url, $_] } @$topic;
    }
    elsif (is_type $topic, 'HASH') {
      next if $seen{refaddr($topic)}++;

      my $base_url = $base_url;    # do not change the global $base_url
      if ($topic->{$id_key} and !ref $topic->{$id_key}) {
        my $id = Mojo::URL->new($topic->{$id_key});
        $id = $id->to_abs($base_url) unless $id->is_abs;
        $self->store->add($id => $topic);
        $base_url = $id;
      }

      my $has_ref = $topic->{'$ref'} && !ref $topic->{'$ref'} && !tied %$topic ? 1 : 0;
      push @refs, [$base_url, $topic] if $has_ref;

      for my $key (keys %$topic) {
        next unless ref $topic->{$key};
        next if $has_ref and $key eq '$ref';
        push @topics, [$base_url, $topic->{$key}];
      }
    }
  }

  while (@refs) {
    my ($base_url, $topic) = @{shift @refs};
    next if is_type $topic, 'BOOL';
    next if !$topic->{'$ref'} or ref $topic->{'$ref'};
    my $base = Mojo::URL->new($base_url || $base_url)->fragment(undef);
    my ($other, $ref_url, $fqn) = $self->_resolve_ref($topic->{'$ref'}, $base, \%root);
    tie %$topic, 'JSON::Validator::Ref', $other, "$ref_url", "$fqn";
    push @refs, [$other, $fqn];
  }
}

sub _id_key { ($_[0]->{version} || 4) < 7 ? 'id' : '$id' }

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
  if (!$attrs{specification} and is_type $schema, 'HASH' and $schema->{'$schema'}) {
    $attrs{specification} = $schema->{'$schema'};
  }
  if (!$attrs{specification} and $self->{version}) {
    $attrs{specification} = sprintf 'http://json-schema.org/draft-%02s/schema#', $self->{version};
  }

  $attrs{formats} ||= $self->{formats} if $self->{formats};
  $attrs{version} ||= $self->{version} if $self->{version};
  $attrs{store} = $store;

  return $self->_schema_class($attrs{specification} || $schema)->new($source, %attrs);
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
  return $schema if ref $schema ne 'HASH';

  my @guard;
  while (my $tied = tied %$schema) {
    push @guard, $tied->ref;
    confess "Seems like you have a circular reference: @guard" if @guard > RECURSION_LIMIT;
    $schema = $tied->schema;
    last if is_type $schema, 'BOOL';
  }

  return $schema;
}

sub _register_root_schema {
  my ($self, $id, $schema) = @_;
  confess "Root schema cannot have a fragment in the 'id'. ($id)" if $id =~ /\#./;
  confess "Root schema cannot have a relative 'id'. ($id)" unless $id =~ /^\w+:/ or -e $id or $id =~ m!^/!;
}

# _resolve() method is used to convert all "id" into absolute URLs and
# resolve all the $ref's that we find inside JSON Schema specification.
sub _resolve {
  my ($self, $schema, $nested) = @_;
  return $schema if is_type $schema, 'BOOL';

  my ($id_key, $id, $cached_id, $resolved) = ($self->_id_key);
  if (ref $schema eq 'HASH') {
    $id        = $schema->{$id_key} // '';
    $cached_id = $self->store->exists($id);
    $resolved  = $cached_id ? $self->store->get($cached_id) : $schema;
  }
  else {
    $cached_id = $self->store->exists($id);
    $id        = $cached_id // $self->store->load($schema);
    $resolved  = $self->store->get($id);
    $id        = $resolved->{$id_key} if is_type($resolved, 'HASH') and $resolved->{$id_key};
  }

  $cached_id //= '';
  $id = Mojo::URL->new("$id");
  $self->_register_root_schema($id => $resolved) if !$nested and "$id";
  $self->store->add($id => $resolved)            if "$id"    and "$id" ne $cached_id;
  $self->_find_and_resolve_refs($id => $resolved) unless $cached_id;

  return $resolved;
}

sub _resolve_ref {
  my ($self, $ref_url, $base_url, $schema) = @_;
  $ref_url = "#$ref_url" if $ref_url =~ m!^/!;

  my $fqn     = Mojo::URL->new($ref_url);
  my $pointer = $fqn->fragment;
  my $other;

  $fqn = $fqn->to_abs($base_url) if "$base_url";
  $other //= $self->store->get($fqn);
  $other //= $self->store->get($fqn->clone->fragment(undef));
  $other //= $self->_resolve($fqn->clone->fragment(undef), 1) if $fqn->is_abs && $fqn ne $base_url;
  $other //= $schema;

  if (defined $pointer and $pointer =~ m!^/!) {
    $other = Mojo::JSON::Pointer->new($other)->get($pointer);
    confess qq[Possibly a typo in schema? Could not find "$pointer" in "$fqn" ($ref_url)] unless defined $other;
  }

  $fqn->fragment($pointer // '');
  return $other, $ref_url, $fqn;
}

# back compat
sub _schema_class {
  my ($self, $spec) = @_;

  # Detect openapiv2 and v3 schemas by content, since no "$schema" is present
  if (ref $spec eq 'HASH' and $spec->{paths}) {
    if ($spec->{swagger} and $spec->{swagger} eq '2.0') {
      $spec = 'http://swagger.io/v2/schema.json';
    }
    elsif ($spec->{openapi} and $spec->{openapi} =~ m!^3\.0\.\d+$!) {
      $spec = 'https://spec.openapis.org/oas/3.0/schema/2019-04-02';
    }
  }

  my $schema_class = $spec && $SCHEMAS{$spec} || 'JSON::Validator::Schema';
  $schema_class =~ s!^\+(.+)$!JSON::Validator::Schema::$1!;
  confess "Could not load $schema_class: $@" unless $schema_class->can('new') or eval "require $schema_class;1";

  return $schema_class if ref $_[0] eq __PACKAGE__;

  my $jv_class           = ref($self) || $self;
  my $short_schema_class = $schema_class =~ m!JSON::Validator::Schema::(.+)! ? $1 : $schema_class;
  my $package            = sprintf 'JSON::Validator::Schema::Backcompat::%s',
    $jv_class =~ m!^JSON::Validator::(.+)! ? $1 : $jv_class;
  return $package if $package->can('new');

  die "package $package: $@" unless eval "package $package; use Mojo::Base '$jv_class'; 1";
  Mojo::Util::monkey_patch($package, $_ => JSON::Validator::Schema->can($_))
    for qw(_register_root_schema bundle contains data errors get id new resolve specification validate);
  return $package;
}

sub _validate {
  my ($self, $data, $path, $schema) = @_;
  $schema = $self->_ref_to_schema($schema);
  return $schema ? () : E $path, [not => 'not'] if is_type $schema, 'BOOL';

  my @errors;
  if ($self->recursive_data_protection) {
    my $seen_addr = join ':', refaddr($schema), (ref $data ? refaddr $data : ++$self->{seen}{scalar});
    return @{$self->{seen}{$seen_addr}} if $self->{seen}{$seen_addr};    # Avoid recursion
    $self->{seen}{$seen_addr} = \@errors;
  }

  local $_[1] = $data->TO_JSON if blessed $data and $data->can('TO_JSON');

  if (my $rules = $schema->{not}) {
    my @e = $self->_validate($_[1], $path, $rules);
    push @errors, E $path, [not => 'not'] unless @e;
  }
  if (my $rules = $schema->{allOf}) {
    push @errors, $self->_validate_all_of($_[1], $path, $rules);
  }
  if (my $rules = $schema->{anyOf}) {
    push @errors, $self->_validate_any_of($_[1], $path, $rules);
  }
  if (my $rules = $schema->{oneOf}) {
    push @errors, $self->_validate_one_of($_[1], $path, $rules);
  }
  if (exists $schema->{if}) {
    my $rules = !$schema->{if} || $self->_validate($_[1], $path, $schema->{if}) ? $schema->{else} : $schema->{then};
    push @errors, $self->_validate($_[1], $path, $rules // {});
  }

  my $type = $schema->{type} || schema_type $schema, $_[1];
  if (ref $type eq 'ARRAY') {
    push @{$self->{temp_schema}}, [map { +{%$schema, type => $_} } @$type];
    push @errors, $self->_validate_any_of_types($_[1], $path, $self->{temp_schema}[-1]);
  }
  elsif ($type) {
    my $method = sprintf '_validate_type_%s', $type;
    push @errors, $self->$method($_[1], $path, $schema);
  }

  return @errors if @errors;

  if (exists $schema->{const}) {
    push @errors, $self->_validate_type_const($_[1], $path, $schema);
  }
  if ($schema->{enum}) {
    push @errors, $self->_validate_type_enum($_[1], $path, $schema);
  }

  return @errors;
}

sub _validate_all_of {
  my ($self, $data, $path, $rules) = @_;
  my (@errors, @errors_with_prefix);

  my $i = 0;
  for my $rule (@$rules) {
    next unless my @e = $self->_validate($_[1], $path, $rule);
    push @errors,             @e;
    push @errors_with_prefix, [$i, @e];
  }
  continue {
    $i++;
  }

  return if not @errors;

  return prefix_errors(allOf => @errors_with_prefix)
    if @errors == 1
    or (grep { $_->details->[1] ne 'type' or $_->path ne ($path || '/') } @errors);

  # combine all 'type' errors at the base path together
  my @details    = map $_->details, @errors;
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

  # favor a non-type error from one of the rules
  if (my @e = grep { $_->details->[1] ne 'type' or $_->path ne ($path || '/') } @errors) {
    return @e;
  }

  # the type didn't match any of the rules: combine the errors together
  my @details    = map $_->details, @errors;
  my $want_types = join '/', uniq map $_->[0], @details;
  return E $path, [$want_types => 'type', $details[-1][2]];
}

sub _validate_any_of {
  my ($self, $data, $path, $rules) = @_;
  my (@errors, @errors_with_prefix);

  my $i = 0;
  for my $rule (@$rules) {
    return unless my @e = $self->_validate($_[1], $path, $rule);
    push @errors,             @e;
    push @errors_with_prefix, [$i, @e];
  }
  continue {
    $i++;
  }

  return prefix_errors(anyOf => @errors_with_prefix)
    if @errors == 1
    or (grep { $_->details->[1] ne 'type' or $_->path ne ($path || '/') } @errors);

  # combine all 'type' errors at the base path together
  my @details    = map $_->details, @errors;
  my $want_types = join '/', uniq map $_->[0], @details;
  return E $path, [anyOf => type => $want_types, $details[-1][2]];
}

sub _validate_one_of {
  my ($self, $data, $path, $rules) = @_;
  my (@errors, @errors_with_prefix);

  my ($i, @passed) = (0);
  for my $rule (@$rules) {
    my @e = $self->_validate($_[1], $path, $rule) or push @passed, $i and next;
    push @errors_with_prefix, [$i, @e];
    push @errors,             @e;
  }
  continue {
    $i++;
  }

  return if @passed == 1;
  return E $path, [oneOf => 'all_rules_match'] unless @errors;
  return E $path, [oneOf => 'n_rules_match', join(', ', @passed)] if @passed;

  return prefix_errors(oneOf => @errors_with_prefix)
    if @errors == 1
    or (grep { $_->details->[1] ne 'type' or $_->path ne ($path || '/') } @errors);

  # the type didn't match any of the rules: combine the errors together
  my @details    = map $_->details, @errors;
  my $want_types = join '/', uniq map $_->[0], @details;
  return E $path, [oneOf => type => $want_types, $details[-1][2]];
}

sub _validate_number_max {
  my ($self, $value, $path, $schema, $expected) = @_;
  my @errors;

  my $cmp_with = $schema->{exclusiveMaximum} // '';
  if (is_type $cmp_with, 'BOOL') {
    push @errors, E $path, [$expected => ex_maximum => $value, $schema->{maximum}] unless $value < $schema->{maximum};
  }
  elsif (is_type $cmp_with, 'NUM') {
    push @errors, E $path, [$expected => ex_maximum => $value, $cmp_with] unless $value < $cmp_with;
  }

  if (exists $schema->{maximum}) {
    my $cmp_with = $schema->{maximum};
    push @errors, E $path, [$expected => maximum => $value, $cmp_with] unless $value <= $cmp_with;
  }

  return @errors;
}

sub _validate_number_min {
  my ($self, $value, $path, $schema, $expected) = @_;
  my @errors;

  my $cmp_with = $schema->{exclusiveMinimum} // '';
  if (is_type $cmp_with, 'BOOL') {
    push @errors, E $path, [$expected => ex_minimum => $value, $schema->{minimum}] unless $value > $schema->{minimum};
  }
  elsif (is_type $cmp_with, 'NUM') {
    push @errors, E $path, [$expected => ex_minimum => $value, $cmp_with] unless $value > $cmp_with;
  }

  if (exists $schema->{minimum}) {
    my $cmp_with = $schema->{minimum};
    push @errors, E $path, [$expected => minimum => $value, $cmp_with] unless $value >= $cmp_with;
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

  $enum = join ', ', map { (!defined or ref) ? Mojo::JSON::encode_json($_) : $_ } @$enum;
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
  return do { warn "Format rule for '$schema->{format}' is missing"; return } unless $code;
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
    push @errors, E $path, [array => minItems => int(@$data), $schema->{minItems}];
  }
  if (defined $schema->{maxItems} and $schema->{maxItems} < @$data) {
    push @errors, E $path, [array => maxItems => int(@$data), $schema->{maxItems}];
  }
  if ($schema->{uniqueItems}) {
    my %uniq;
    for (@$data) {
      next if !$uniq{data_checksum($_)}++;
      push @errors, E $path, [array => 'uniqueItems'];
      last;
    }
  }

  if (exists $schema->{contains}) {
    my @e;
    for my $i (0 .. @$data - 1) {
      my @tmp = $self->_validate($data->[$i], "$path/$i", $schema->{contains});
      push @e, \@tmp if @tmp;
    }
    push @errors, map {@$_} @e if @e >= @$data;
    push @errors, E $path, [array => 'contains'] if not @$data;
  }

  if (ref $schema->{items} eq 'ARRAY') {
    my $additional_items = $schema->{additionalItems} // {};
    my @rules            = @{$schema->{items}};

    if ($additional_items) {
      push @rules, $additional_items while @rules < @$data;
    }

    if (@rules >= @$data) {
      for my $i (0 .. @$data - 1) {
        push @errors, $self->_validate($data->[$i], "$path/$i", $rules[$i]);
      }
    }
    elsif (!$additional_items) {
      push @errors, E $path, [array => additionalItems => int(@$data), int(@rules)];
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

  # String that looks like a boolean
  if (defined $value and $self->{coerce}{booleans}) {
    $_[1] = false if $value =~ m!^(0|false|)$!;
    $_[1] = true  if $value =~ m!^(1|true)$!;
  }

  return if is_type $_[1], 'BOOL';
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
  return E $path, [null => type => data_type $value];
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
      if !$self->{coerce}{numbers} or $value !~ /^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?$/;
    $_[1] = 0 + $value;    # coerce input value
  }

  push @errors, $self->_validate_format($value, $path, $schema) if $schema->{format};
  push @errors, $self->_validate_number_max($value, $path, $schema, $expected);
  push @errors, $self->_validate_number_min($value, $path, $schema, $expected);

  my $d = $schema->{multipleOf};
  push @errors, E $path, [$expected => multipleOf => $d] if $d and ($value / $d) =~ /\.[^0]+$/;

  return @errors;
}

sub _validate_type_object {
  my ($self, $data, $path, $schema) = @_;

  return E $path, [object => type => data_type $data] unless ref $data eq 'HASH';

  my @errors;
  my @dkeys = sort keys %$data;
  if (defined $schema->{maxProperties} and $schema->{maxProperties} < @dkeys) {
    push @errors, E $path, [object => maxProperties => int(@dkeys), $schema->{maxProperties}];
  }
  if (defined $schema->{minProperties} and $schema->{minProperties} > @dkeys) {
    push @errors, E $path, [object => minProperties => int(@dkeys), $schema->{minProperties}];
  }
  if (exists $schema->{propertyNames}) {
    for my $name (keys %$data) {
      next unless my @e = $self->_validate($name, $path, $schema->{propertyNames});
      push @errors, prefix_errors propertyName => map [$name, $_], @e;
    }
  }

  my %rules;
  for my $k (keys %{$schema->{properties} || {}}) {
    my $r = $schema->{properties}{$k};
    push @{$rules{$k}}, $r;
    if ($self->{coerce}{defaults} and ref $r eq 'HASH' and exists $r->{default} and !exists $data->{$k}) {
      $data->{$k} = $r->{default};
    }
  }

  for my $p (keys %{$schema->{patternProperties} || {}}) {
    my $r = $schema->{patternProperties}{$p};
    push @{$rules{$_}}, $r for sort grep { $_ =~ /$p/ } @dkeys;
  }

  my $additional = exists $schema->{additionalProperties} ? $schema->{additionalProperties} : {};
  if ($additional) {
    $additional = {} unless is_type $additional, 'HASH';
    $rules{$_} ||= [$additional] for @dkeys;
  }
  elsif (my @k = grep { !$rules{$_} } @dkeys) {
    local $" = ', ';
    return E $path, [object => additionalProperties => join ', ', sort @k];
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
      push @errors, $self->_validate_type_object($data, $path, $schema->{dependencies}{$k});
    }
  }

  for my $k (sort keys %rules) {
    for my $r (@{$rules{$k}}) {
      next unless exists $data->{$k};
      $r = $self->_ref_to_schema($r);
      my @e = $self->_validate($data->{$k}, json_pointer($path, $k), $r);
      push @errors, @e;
      next if @e or !is_type $r, 'HASH';
      push @errors, $self->_validate_type_enum($data->{$k}, json_pointer($path, $k), $r)  if $r->{enum};
      push @errors, $self->_validate_type_const($data->{$k}, json_pointer($path, $k), $r) if $r->{const};
    }
  }

  return @errors;
}

sub _validate_type_string {
  my ($self, $value, $path, $schema) = @_;
  my @errors;

  if (!$schema->{type} and !defined $value) {
    return;
  }
  if (!defined $value or ref $value) {
    return E $path, [string => type => data_type $value];
  }
  if (B::svref_2object(\$value)->FLAGS & (B::SVp_IOK | B::SVp_NOK) and 0 + $value eq $value and $value * 0 == 0) {
    return E $path, [string => type => data_type $value] unless $self->{coerce}{strings};
    $_[1] = "$value";    # coerce input value
  }
  if ($schema->{format}) {
    push @errors, $self->_validate_format($value, $path, $schema);
  }
  if (defined $schema->{maxLength}) {
    if (length($value) > $schema->{maxLength}) {
      push @errors, E $path, [string => maxLength => length($value), $schema->{maxLength}];
    }
  }
  if (defined $schema->{minLength}) {
    if (length($value) < $schema->{minLength}) {
      push @errors, E $path, [string => minLength => length($value), $schema->{minLength}];
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

=head1 ERROR OBJECT

The methods L</validate> and the function L</validate_json> returns a list of
L<JSON::Validator::Error> objects when the input data violates the L</schema>.

=head1 FUNCTIONS

=head2 joi

DEPRECATED.

=head2 validate_json

DEPRECATED.

=head1 ATTRIBUTES

=head2 cache_paths

Proxy attribtue for L<JSON::Validator::Store/cache_paths>.

=head2 formats

  my $hash_ref  = $jv->formats;
  my $jv = $jv->formats(\%hash);

Holds a hash-ref, where the keys are supported JSON type "formats", and
the values holds a code block which can validate a given format. A code
block should return C<undef> on success and an error string on error:

  sub { return defined $_[0] && $_[0] eq "42" ? undef : "Not the answer." };

See L<JSON::Validator::Formats> for a list of supported formats.

=head2 recursive_data_protection

  my $jv = $jv->recursive_data_protections( $boolean );
  my $boolean = $jv->recursive_data_protection;

Recursive data protection is active by default, however it can be deactivated
by assigning a false value to the L</recursive_data_protection> attribute.

Recursive data protection can have a noticeable impact on memory usage when
validating large data structures. If you are encountering issues with memory
and you can guarantee that you do not have any loops in your data structure
then deactivating the recursive data protection may help.

This attribute is EXPERIMENTAL and may change in a future release.

B<Disclaimer: Use at your own risk, if you have any doubt then don't use it>

=head2 ua

Proxy attribtue for L<JSON::Validator::Store/ua>.

=head2 version

DEPRECATED.

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

C<$schema> will be a L<JSON::Validator::Schema> object when loaded,
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

DEPRECATED.

=head2 validate

  my @errors = $jv->validate($data);
  my @errors = $jv->validate($data, $schema);

Validates C<$data> against a given JSON L</schema>. C<@errors> will
contain validation error objects, in a predictable order (specifically,
ASCIIbetically sorted by the error objects' C<path>) or be an empty
list on success.

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
