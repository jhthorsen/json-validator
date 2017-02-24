package JSON::Validator;
use Mojo::Base -base;

use Exporter 'import';
use JSON::Validator::Error;
use Mojo::File 'path';
use Mojo::JSON;
use Mojo::JSON::Pointer;
use Mojo::URL;
use Mojo::Util 'deprecated';
use B;
use Scalar::Util;

use constant VALIDATE_HOSTNAME => eval 'require Data::Validate::Domain;1';
use constant VALIDATE_IP       => eval 'require Data::Validate::IP;1';

use constant DEBUG => $ENV{JSON_VALIDATOR_DEBUG} || 0;

our $VERSION   = '0.94';
our @EXPORT_OK = 'validate_json';

my $BUNDLED_CACHE_DIR = path(path(__FILE__)->dirname, qw(Validator cache));
my $HTTP_SCHEME_RE = qr{^https?:};

sub E { JSON::Validator::Error->new(@_) }
sub S { Mojo::Util::md5_sum(Data::Dumper->new([@_])->Sortkeys(1)->Useqq(1)->Dump); }

has cache_paths => sub {
  my $self = shift;
  my @paths = split /:/, ($ENV{JSON_VALIDATOR_CACHE_PATH} || '');

  if ($ENV{JSON_VALIDATOR_CACHE_DIR}) {
    warn "JSON_VALIDATOR_CACHE_DIR is deprecated in favor of JSON_VALIDATOR_CACHE_PATH\n"
      unless $ENV{HARNESS_ACTIVE};
    push @paths, split /:/, ($ENV{JSON_VALIDATOR_CACHE_DIR} || '');
  }

  push @paths, $BUNDLED_CACHE_DIR;
  return \@paths;
};

has formats => sub { shift->_build_formats };

has resolver => sub { \&_resolver };

has ua => sub {
  require Mojo::UserAgent;
  my $ua = Mojo::UserAgent->new;
  $ua->proxy->detect;
  $ua->max_redirects(3);
  $ua;
};

sub coerce {
  my $self = shift;
  return $self->{coerce} ||= {} unless @_;
  $self->{coerce}
    = $_[0] eq '1' ? {booleans => 1, numbers => 1, strings => 1} : ref $_[0] ? {%{$_[0]}} : {@_};
  $self;
}

sub schema {
  my ($self, $schema) = @_;

  if (@_ == 1) {
    return $self->{schema};
  }
  elsif (ref $schema eq 'HASH') {
    $schema->{id} ||= $self->_default_id($schema);
    warn "[JSON::Validator] Schema from hash. id=$schema->{id}\n" if DEBUG;
    $schema = $self->_register_document($schema, $schema->{id});
  }
  else {
    $schema = path($schema)->to_abs if -e $schema;
    $schema = $self->_load_schema($schema);
  }

  $self->{schema} = $self->_resolve_schema($schema, $schema->data->{id});
  $self;
}

sub singleton { state $validator = shift->new }

sub validate {
  my ($self, $data, $schema) = @_;
  $schema ||= $self->schema->data;
  return E '/', 'No validation rules defined.' unless $schema and %$schema;
  local $self->{schema} = Mojo::JSON::Pointer->new($schema);
  local $self->{seen}   = {};
  return $self->_validate($data, '', $schema);
}

sub validate_json {
  __PACKAGE__->singleton->schema($_[1])->validate($_[0]);
}

sub _build_formats {
  return {
    'date-time' => \&_is_date_time,
    'email'     => \&_is_email,
    'hostname'  => VALIDATE_HOSTNAME ? \&Data::Validate::Domain::is_domain : \&_is_domain,
    'ipv4'      => VALIDATE_IP ? \&Data::Validate::IP::is_ipv4 : \&_is_ipv4,
    'ipv6'      => VALIDATE_IP ? \&Data::Validate::IP::is_ipv6 : \&_is_ipv6,
    'regex'     => \&_is_regex,
    'uri'       => \&_is_uri,
  };
}

sub _load_schema {
  my ($self, $url, $parent) = @_;
  my ($namespace, $scheme) = ("$url", "file");
  my $doc;

  if ($namespace =~ $HTTP_SCHEME_RE) {
    $url = Mojo::URL->new($url);
    ($namespace, $scheme) = ($url->clone->fragment(undef)->to_string, $url->scheme);
  }
  elsif ($namespace =~ m!^data://(.*)!) {
    $scheme = 'data';
  }
  elsif ($parent and $parent =~ $HTTP_SCHEME_RE) {
    $parent = Mojo::URL->new($parent);
    $url =~ s!#.*!!;
    $url = $parent->path($parent->path->merge($url)->canonicalize);
    ($namespace, $scheme) = ($url->to_string, $url->scheme);
  }
  elsif ($parent) {
    $url =~ s!#.*!!;
    $url = path(path($parent)->dirname, split '/', $url);
    $namespace = eval { $url->to_abs->to_string } || $url;
  }

  # Make sure we create the correct namespace if not already done by Mojo::URL
  $namespace =~ s!#.*$!! if $namespace eq $url;

  return $self->{cached}{$namespace} if $self->{cached}{$namespace};
  return eval {
    warn "[JSON::Validator] Loading schema $url namespace=$namespace scheme=$scheme\n"
      if DEBUG;
    $doc
      = $scheme eq 'file' ? path($namespace)->slurp
      : $scheme eq 'data' ? $self->_load_schema_from_data($url, $namespace)
      :                     $self->_load_schema_from_url($url, $namespace);
    $self->_register_document($self->_load_schema_from_text(\$doc), $namespace);
  } || do {
    $doc ||= '';
    die "Could not load document from $url: $@ ($doc)" if DEBUG;
    die "Could not load document from $url: $@";
  };
}

sub _load_schema_from_data {
  my ($self, $url, $namespace) = @_;
  require Mojo::Loader;
  my ($module, $file) = $namespace =~ m!^data://([^/]+)/(.*)$! or die "Invalid URL: $namespace.";
  Mojo::Loader::data_section($module, $file)
    || die "$file could not be found in __DATA__ section of $module.";
}

sub _load_schema_from_text {
  my ($self, $text) = @_;
  my $visit;

  # JSON
  return Mojo::JSON::decode_json($$text) if $$text =~ /^\s*\{/s;

  # YAML
  $visit = sub {
    my $v = shift;
    $visit->($_) for grep { ref $_ eq 'HASH' } values %$v;
    return $v unless $v->{type} and $v->{type} eq 'boolean' and exists $v->{default};
    %$v = (%$v, default => $v->{default} ? Mojo::JSON->true : Mojo::JSON->false);
    return $v;
  };

  local $YAML::Syck::ImplicitTyping = 1;
  return $visit->($self->coerce(1)->_yaml_module->can('Load')->($$text));
}

sub _load_schema_from_url {
  my ($self, $url, $namespace) = @_;
  my $cache_path = $self->cache_paths->[0];
  my $cache_file = Mojo::Util::md5_sum($namespace);
  my $tx;

  for (@{$self->cache_paths}) {
    my $path = path $_, $cache_file;
    next unless -r $path;
    warn "[JSON::Validator] Loading cached file $path\n" if DEBUG;
    return $path->slurp;
  }

  $tx = $self->ua->get($url);
  die $tx->error->{message} if $tx->error;

  if ($cache_path and $cache_path ne $BUNDLED_CACHE_DIR and -w $cache_path) {
    $cache_file = path $cache_path, $cache_file;
    warn "[JSON::Validator] Caching $namespace to $cache_file\n" unless $ENV{HARNESS_ACTIVE};
    $cache_file->spurt($tx->res->body);
  }

  return $tx->res->body;
}

sub _default_id {
  my $path = path($0)->to_abs;
  state $id = 0;
  $path = $path->dirname if $path;
  $path = path() unless $path;
  return path($path, sprintf 'json-validator-%s.json', ++$id)->to_string;
}

sub _register_document {
  my ($self, $doc, $namespace) = @_;

  $doc = Mojo::JSON::Pointer->new($doc);
  $namespace = Mojo::URL->new($namespace) unless ref $namespace;
  $namespace->fragment(undef);

  $self->{cached}{$namespace} = $doc;
  $doc->data->{id} ||= "$namespace";
  $self->{cached}{$doc->data->{id}} = $doc;

  warn "[JSON::Validator] Register id=$doc->{data}{id} namespace=$namespace\n" if DEBUG;
  return $doc;
}

# This method is used to resolve all the $ref's that we find inside JSON Schema
# specification.
#
# $namespace is typically the "id" part at the top level of the schema
# specification. Meaning some kind of URL. In the case of Swagger: Just make
# something up instead using _default_id()
sub _resolve_schema {
  my ($self, $schema, $namespace) = @_;
  my (@topics, @refs);

  # The if is true if we have already resolved this $namespace. This happens if
  # the same specification has "$ref" with the same value multiple times.
  # There's no need to resolve the same schema twice.
  return $self->{resolved}{$namespace} if $self->{resolved}{$namespace};

  warn "[JSON::Validator] Resolving schema $namespace\n" if DEBUG;
  $self->{resolved}{$namespace} = Mojo::JSON::Pointer->new({%{$schema->data}});
  @topics = ($self->{resolved}{$namespace}->data);

  # This while loop will traverse the whole specification and and track down
  # each and every "$ref" it finds. @topics is a list of all the data
  # structures that it finds. Note that is start out with just having one item:
  # A hash-ref to the complete specification, but as it goes along, the while()
  # loop will track down more objects and arrays inside the specification and
  # then loop over those as well, util it has "visited" the whole document.
  while (@topics) {
    my $topic = shift @topics;
    if (UNIVERSAL::isa($topic, 'HASH')) {
      for my $k (sort keys %$topic) {
        my $v = $topic->{$k};

        # int($v) returns the memory address of the reference. The "if" below
        # will not resolve the same "$ref" over again.
        next if ref $v and $self->{seen}{int($v)}++;

        # Make sure we do not modify the input data structure.
        # Changing the input makes t/expand.t in swagger2.git fail.
        $topic->{$k} = [@$v] if UNIVERSAL::isa($v, 'ARRAY');
        $topic->{$k} = {%$v} if UNIVERSAL::isa($v, 'HASH');

        push @topics, $topic->{$k} if ref $topic->{$k};
        push @refs, $topic if $k eq '$ref' and !ref $v;
      }
    }
    elsif (UNIVERSAL::isa($topic, 'ARRAY')) {
      push @topics, @$topic;
    }
  }

  # Resolve all the "$ref" we found. This will call _resolve_schema() again.
  $self->resolver->($self, $namespace, \@refs);
  $self->{resolved}{$namespace};
}

sub _resolver {
  my ($self, $namespace, $refs) = @_;

  # Seconds step: Resolve $ref
  for my $topic (@$refs) {
    my $ref = $topic->{'$ref'} or next;    # already resolved?
    $ref = "#/definitions/$ref" if $ref =~ /^\w+$/;    # TODO: Figure out if this could be removed
    $ref = Mojo::URL->new($namespace)->fragment($ref) if $ref =~ s!^\#!!;
    $ref = Mojo::URL->new($ref) unless ref $ref;

    warn "[JSON::Validator] Resolving ref $ref defined in $namespace\n" if DEBUG == 2;
    my $look_in = $self->{resolved}{$ref->clone->fragment(undef)};

    if (!$look_in) {
      $look_in = $self->_load_schema($ref, $namespace);
      $look_in = $self->_resolve_schema($look_in, $look_in->data->{id} || $namespace);
      warn "[JSON::Validator] Will look for $ref in $look_in->{data}{id}\n" if DEBUG == 2;
    }

    $ref = $look_in->get($ref->fragment || '')
      || die qq[Could not find "$topic->{'$ref'}" ($ref). Typo in schema "$namespace"?];
    %$topic = %$ref;
    delete $topic->{id} unless ref $topic->{id};    # TODO: Is this correct?
  }
}

sub _validate {
  my ($self, $data, $path, $schema) = @_;
  my ($type, @errors);

  # Avoid recursion
  return if ref $data and $self->{seen}{"$schema\:$data"}++;

  # Make sure we validate plain data and not a perl object
  $data = $data->TO_JSON if Scalar::Util::blessed($data) and UNIVERSAL::can($data, 'TO_JSON');
  $type = $schema->{type} || _guess_schema_type($schema, $data);

  # Test base schema before allOf, anyOf or oneOf
  if (ref $type eq 'ARRAY') {
    push @errors, $self->_validate_any_of($data, $path, [map { +{%$schema, type => $_} } @$type]);
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

  return @errors;
}

sub _validate_all_of {
  my ($self, $data, $path, $rules) = @_;
  my $type = _guess_data_type($data);
  my (@errors, @expected);

  for my $rule (@$rules) {
    my @e = $self->_validate($data, $path, $rule) or next;
    my $schema_type = _guess_schema_type($rule);
    push @errors, [@e] and next if !$schema_type or $schema_type eq $type;
    push @expected, $schema_type;
  }

  warn "[JSON::Validator] allOf @{[$path||'/']} == [@errors]\n" if DEBUG == 2;
  my $expected = join ' or ', _uniq(@expected);
  return E $path, "allOf failed: Expected $expected, not $type."
    if $expected and @errors + @expected == @$rules;
  return E $path, sprintf 'allOf failed: %s', _merge_errors(@errors) if @errors;
  return;
}

sub _validate_any_of {
  my ($self, $data, $path, $rules) = @_;
  my $type = _guess_data_type($data);
  my (@e, @errors, @expected);

  for my $rule (@$rules) {
    @e = $self->_validate($data, $path, $rule);
    if (!@e) {
      warn "[JSON::Validator] anyOf @{[$path||'/']} == success\n" if DEBUG == 2;
      return;
    }
    my $schema_type = _guess_schema_type($rule);
    push @errors, [@e] and next if !$schema_type or $schema_type eq $type;
    push @expected, $schema_type;
  }

  warn "[JSON::Validator] anyOf @{[$path||'/']} == [@errors]\n" if DEBUG == 2;
  my $expected = join ' or ', _uniq(@expected);
  return E $path, "anyOf failed: Expected $expected, got $type." unless @errors;
  return E $path, sprintf "anyOf failed: %s", _merge_errors(@errors);
}

sub _validate_one_of {
  my ($self, $data, $path, $rules) = @_;
  my $type = _guess_data_type($data);
  my (@errors, @expected);

  for my $rule (@$rules) {
    my @e = $self->_validate($data, $path, $rule) or next;
    my $schema_type = _guess_schema_type($rule);
    push @errors, [@e] and next if !$schema_type or $schema_type eq $type;
    push @expected, $schema_type;
  }

  if (@errors + @expected + 1 == @$rules) {
    warn "[JSON::Validator] oneOf @{[$path||'/']} == success\n" if DEBUG == 2;
    return;
  }

  if (DEBUG == 2) {
    warn sprintf "[JSON::Validator] oneOf %s == failed=%s/%s / @errors\n", $path || '/',
      @errors + @expected, int @$rules;
  }

  my $expected = join ' or ', _uniq(@expected);
  return E $path, 'All of the oneOf rules match.' unless @errors + @expected;
  return E $path, "oneOf failed: Expected $expected, got $type." unless @errors;
  return E $path, sprintf 'oneOf failed: %s', _merge_errors(@errors);
}

sub _validate_type_enum {
  my ($self, $data, $path, $schema) = @_;
  my $enum = $schema->{enum};
  my $m    = S $data;

  for my $i (@$enum) {
    return
      if !(defined $data and $self->_validate_type_boolean($data, $path))
      and _is_true($data) == _is_true($i);
    return if $m eq S $i;
  }

  local $" = ', ';
  return E $path, "Not in enum list: @$enum.";
}

sub _validate_format {
  my ($self, $value, $path, $schema) = @_;
  my $code = $self->formats->{$schema->{format}};
  return if $code and $code->($value);
  return do { warn "Format rule for '$schema->{format}' is missing"; return } unless $code;
  return E $path, "Does not match $schema->{format} format.";
}

sub _validate_type_any { }

sub _validate_type_array {
  my ($self, $data, $path, $schema) = @_;
  my @errors;

  if (ref $data ne 'ARRAY') {
    return E $path, _expected(array => $data);
  }
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
      push @errors, $self->_validate($data->[$i], "$path/$i", $schema->{items});
    }
  }

  return @errors;
}

sub _validate_type_boolean {
  my ($self, $value, $path, $schema) = @_;

  return if UNIVERSAL::isa($value, 'JSON::PP::Boolean');
  return if Scalar::Util::blessed($value) and ("$value" eq "1" or !$value);

  if (  defined $value
    and $self->{coerce}{booleans}
    and (B::svref_2object(\$value)->FLAGS & B::SVp_NOK or $value =~ /^(true|false)$/))
  {
    $_[1] = $value ? Mojo::JSON->true : Mojo::JSON->false;
    return;
  }

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
  unless (B::svref_2object(\$value)->FLAGS & (B::SVp_IOK | B::SVp_NOK)
    and 0 + $value eq $value
    and $value * 0 == 0)
  {
    return E $path, "Expected $expected - got string."
      if !$self->{coerce}{numbers} or $value !~ /^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?$/;
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
    if (($value / $d) =~ /\.[^0]+$/) {
      push @errors, E $path, "Not multiple of $d.";
    }
  }

  return @errors;
}

sub _validate_type_object {
  my ($self, $data, $path, $schema) = @_;
  my %required = map { ($_ => 1) } @{$schema->{required} || []};
  my ($additional, @errors, %rules);

  if (ref $data ne 'HASH') {
    return E $path, _expected(object => $data);
  }
  if (defined $schema->{maxProperties} and $schema->{maxProperties} < keys %$data) {
    push @errors, E $path, sprintf 'Too many properties: %s/%s.', int(keys %$data),
      $schema->{maxProperties};
  }
  if (defined $schema->{minProperties} and $schema->{minProperties} > keys %$data) {
    push @errors, E $path, sprintf 'Not enough properties: %s/%s.', int(keys %$data),
      $schema->{minProperties};
  }

  while (my ($k, $r) = each %{$schema->{properties}}) {
    push @{$rules{$k}}, $r if exists $data->{$k} or $required{$k};
  }
  while (my ($p, $r) = each %{$schema->{patternProperties}}) {
    push @{$rules{$_}}, $r for grep { $_ =~ /$p/ } keys %$data;
  }

  $additional = exists $schema->{additionalProperties} ? $schema->{additionalProperties} : {};
  if ($additional) {
    $additional = {} unless ref $additional eq 'HASH';
    $rules{$_} ||= [$additional] for keys %$data;
  }
  else {
    # Special case used internally when validating schemas: This module adds "id"
    # on the top level which might conflict with very strict schemas, so we have to
    # remove it again unless there's a rule.
    local $rules{id} = 1 if !$path and exists $data->{id};

    if (my @keys = grep { !$rules{$_} } keys %$data) {
      local $" = ', ';
      return E $path, "Properties not allowed: @keys.";
    }
  }

  for my $k (keys %required) {
    next if exists $data->{$k};
    push @errors, E _path($path, $k), 'Missing property.';
    delete $rules{$k};
  }

  for my $k (keys %rules) {
    for my $r (@{$rules{$k}}) {
      if (!exists $data->{$k} and exists $schema->{default}) {
        $data->{$k} = $r->{default};
      }
      else {
        my @e = $self->_validate($data->{$k}, _path($path, $k), $r);
        push @errors, @e;
        push @errors, $self->_validate_type_enum($data->{$k}, _path($path, $k), $r)
          if $r->{enum} and !@e;
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
  if (  B::svref_2object(\$value)->FLAGS & (B::SVp_IOK | B::SVp_NOK)
    and 0 + $value eq $value
    and $value * 0 == 0)
  {
    return E $path, "Expected string - got number." unless $self->{coerce}{strings};
    $_[1] = "$value";    # coerce input value
  }
  if ($schema->{format}) {
    push @errors, $self->_validate_format($value, $path, $schema);
  }
  if (defined $schema->{maxLength}) {
    if (length($value) > $schema->{maxLength}) {
      push @errors, E $path, sprintf "String is too long: %s/%s.", length($value),
        $schema->{maxLength};
    }
  }
  if (defined $schema->{minLength}) {
    if (length($value) < $schema->{minLength}) {
      push @errors, E $path, sprintf "String is too short: %s/%s.", length($value),
        $schema->{minLength};
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
  return 'boolean' if $blessed and ("$_" eq "1" or !"$_");
  return 'number'
    if B::svref_2object(\$_)->FLAGS & (B::SVp_IOK | B::SVp_NOK)
    and 0 + $_ eq $_
    and $_ * 0 == 0;
  return $blessed || 'string';
}

sub _guess_schema_type {
  return $_[0]->{type} if $_[0]->{type};
  return _guessed_right($_[1], 'object') if $_[0]->{additionalProperties};
  return _guessed_right($_[1], 'object') if $_[0]->{patternProperties};
  return _guessed_right($_[1], 'object') if $_[0]->{properties};
  return _guessed_right($_[1], 'object')
    if defined $_[0]->{maxProperties}
    or defined $_[0]->{minProperties};
  return _guessed_right($_[1], 'array')  if $_[0]->{additionalItems};
  return _guessed_right($_[1], 'array')  if $_[0]->{items};
  return _guessed_right($_[1], 'array')  if $_[0]->{uniqueItems};
  return _guessed_right($_[1], 'array')  if defined $_[0]->{maxItems} or defined $_[0]->{minItems};
  return _guessed_right($_[1], 'string') if $_[0]->{pattern};
  return _guessed_right($_[1], 'string')
    if defined $_[0]->{maxLength}
    or defined $_[0]->{minLength};
  return _guessed_right($_[1], 'number') if $_[0]->{multipleOf};
  return _guessed_right($_[1], 'number') if defined $_[0]->{maximum} or defined $_[0]->{minimum};
  return 'enum' if $_[0]->{enum};
  return undef;
}

sub _guessed_right {
  return $_[1] unless defined $_[0];
  return _guess_data_type($_[0]) eq $_[1] ? $_[1] : undef;
}

sub _is_date_time {
  $_[0] =~ qr/
    ^(\d+)-(\d+)-(\d+)\D+(\d+):(\d+):(\d+(?:\.\d+)?)   # Date and time
    (?:Z|([+-])(\d+):(\d+))?$                          # Offset
  /xi;
}

sub _is_domain { warn "Data::Validate::Domain is not installed"; return; }

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

sub _is_true {
  local $_ = $_[0];
  return 0 + $_ if ref $_ and !Scalar::Util::blessed($_);
  return 0 if !$_ or /^(n|false|off)/i;
  return 1;
}

sub _is_regex {
  eval {qr{$_[0]}};
}
sub _is_uri { $_[0] =~ qr!^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?!o; }

sub _merge_errors {
  join ' ', map {
    my $e = $_;
    (@$e == 1) ? $e->[0]{message} : sprintf '(%s)', join '. ', map { $_->{message} } @$e;
  } @_;
}

sub _path {
  local $_ = $_[1];
  s!~!~0!g;
  s!/!~1!g;
  "$_[0]/$_";
}

sub _uniq {
  my %uniq;
  grep { !$uniq{$_}++ } @_;
}

# Please report if you need to manually monkey patch this function
# https://github.com/jhthorsen/json-validator/issues
sub _yaml_module {
  state $yaml_module = do {
    require List::Util;
    my @modules = qw(YAML::XS YAML::Syck);                                  # subject to change
    my $module = (List::Util::first { eval "require $_;1" } @modules)[0];
    die "Need to install one of these YAML modules: @modules (YAML::XS is recommended)"
      unless $module;
    warn "[JSON::Validator] Using $module to parse YAML\n" if DEBUG;
    $module;
  };
}

1;

=encoding utf8

=head1 NAME

JSON::Validator - Validate data against a JSON schema

=head1 VERSION

0.94

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

This module can be used standalone, but if you want to define a specification
for your webserver's API, then have a look at L<Mojolicious::Plugin::OpenAPI>,
which will replace L<Mojolicious::Plugin::Swagger2>.

=head2 Supported schema formats

L<JSON::Validator> can load JSON schemas in multiple formats: Plain perl data
structured (as shown in L</SYNOPSIS>) or files on disk/web in the JSON/YAML
format. The JSON parsing is done using L<Mojo::JSON>, while the YAML parsing
is done with an optional modules which need to be installed manually.
L<JSON::Validator> will look for the YAML modules in this order: L<YAML::XS>,
L<YAML::Syck>. The order is set by which module that performs the best, so it
might change in the future.

=head2 Resources

Here are some resources that are related to JSON schemas and validation:

=over 4

=item * L<http://json-schema.org/documentation.html>

=item * L<http://spacetelescope.github.io/understanding-json-schema/index.html>

=item * L<https://github.com/json-schema/json-schema/>

=item * L<Swagger2>

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

=item * JSON schema, draft 4

Web page: L<http://json-schema.org>

C<$ref>: L<http://json-schema.org/draft-04/schema#>

=item * JSON schema for JSONPatch files

Web page: L<http://jsonpatch.com>

C<$ref>: L<http://json.schemastore.org/json-patch#>

=item * Swagger / OpenAPI specification, version 2

Web page: L<https://openapis.org>

C<$ref>: L<http://swagger.io/v2/schema.json#>

=item * Custom error document

There is a custom schema used by L<Mojolicious::Plugin::OpenAPI> as a default
error document. This document might be extended later, but it will always be
backward compatible.

Specification: L<https://github.com/jhthorsen/json-validator/blob/master/lib/JSON/Validator/cache/630949337805585c8e52deea27d11419>

C<$ref>: L<http://git.io/vcKD4#>.

=item * Swagger Petstore

This is used for unit tests, and should probably not be relied on by external
users.

=back

=head1 ERROR OBJECT

=head2 Overview

The method L</validate> and the function L</validate_json> returns
error objects when the input data violates the L</schema>. Each of
the objects looks like this:

  bless {
    message => "Some description",
    path => "/json/path/to/node",
  }, "JSON::Validator::Error"

See also L<JSON::Validator::Error>.

=head2 Operators

The error object overloads the following operators:

=over 4

=item * bool

Returns a true value.

=item * string

Returns the "path" and "message" part as a string: "$path: $message".

=back

=head2 Special cases

Have a look at the L<test suite|https://github.com/jhthorsen/json-validator/tree/master/t>
for documented examples of the error cases. Especially look at C<jv-allof.t>,
C<jv-anyof.t> and C<jv-oneof.t>.

The special cases for "allOf", "anyOf" and "oneOf" will contain the error messages
from all the failing rules below. It can be a bit hard to read, so if the error message
is long, then you might want to run a smaller test with C<JSON_VALIDATOR_DEBUG=1>.

Example error object:

  bless {
    message => "(String is too long: 8/5. String is too short: 8/12)",
    path => "/json/path/to/node",
  }, "JSON::Validator::Error"

Note that these error messages are subject for change. Any suggestions are most
welcome!

=head1 FUNCTIONS

=head2 validate_json

  use JSON::Validator "validate_json";
  @errors = validate_json $data, $schema;

This can be useful in web applications:

  @errors = validate_json $c->req->json, "data://main/spec.json";

See also L</validate> and L</ERROR OBJECT> for more details.

=head1 ATTRIBUTES

=head2 cache_paths

  $self = $self->cache_paths(\@paths);
  $array_ref = $self->cache_paths;

A list of directories to where cached specifications are stored. Defaults to
C<JSON_VALIDATOR_CACHE_PATH> environment variable and the specs that is bundled
with this distribution.

C<JSON_VALIDATOR_CACHE_PATH> can be a list of directories, each separated by ":".

See L</Bundled specifications> for more details.

=head2 formats

  $hash_ref = $self->formats;
  $self = $self->formats(\%hash);

Holds a hash-ref, where the keys are supported JSON type "formats", and
the values holds a code block which can validate a given format.

Note! The modules mentioned below are optional.

=over 4

=item * date-time

An RFC3339 timestamp in UTC time. This is formatted as
"YYYY-MM-DDThh:mm:ss.fffZ". The milliseconds portion (".fff") is optional

=item * email

Validated against the RFC5322 spec.

=item * hostname

Will be validated using L<Data::Validate::Domain> if installed.

=item * ipv4

Will be validated using L<Data::Validate::IP> if installed or
fall back to a plain IPv4 IP regex.

=item * ipv6

Will be validated using L<Data::Validate::IP> if installed.

=item * regex

EXPERIMENTAL. Will check if the string is a regex, using C<qr{...}>.

=item * uri

Validated against the RFC3986 spec.

=back

=head2 resolver

  $code = $self->resolver;
  $self = $self->resolver(sub { my ($self, $namespace, $refs) = @_; });

Set this to a sub without any logic if you want to skip resolving references,
like this:

  $self->resolver(sub {});

This attribute is EXPERIMENTAL.

=head2 ua

  $ua = $self->ua;
  $self = $self->ua(Mojo::UserAgent->new);

Holds a L<Mojo::UserAgent> object, used by L</schema> to load a JSON schema
from remote location.

Note that the default L<Mojo::UserAgent> will detect proxy settings and have
L<Mojo::UserAgent/max_redirects> set to 3. (These settings are EXPERIMENTAL
and might change without a warning)

=head1 METHODS

=head2 coerce

  $self = $self->coerce(booleans => 1, numbers => 1, strings => 1);
  $self = $self->coerce({booleans => 1, numbers => 1, strings => 1});
  $self = $self->coerce(1) # enable all
  $hash = $self->coerce;

Set the given type to coerce. Before enabling coercion this module is very
strict when it comes to validating types. Example: The string C<"1"> is not
the same as the number C<1>, unless you have coercion enabled.

WARNING! Enabling coercion might hide bugs in your api, which would have been
detected if you were strict. For example JavaScript is very picky on a number
being an actual number. This module tries it best to convert the data on the
fly into the proper value, but this means that you unit tests might be ok,
but the client side libraries (that care about types) might break.

Loading a YAML document will enable "booleans" automatically. This feature is
experimental, but was added since YAML has no real concept of booleans, such
as L<Mojo::JSON> or other JSON parsers.

The coercion rules are EXPERIMENTAL and will be tighten/loosen if
bugs are reported. See L<https://github.com/jhthorsen/json-validator/issues/8>
for more details.

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

=head2 singleton

  $self = $class->singleton;

Returns the L<JSON::Validator> object used by L</validate_json>.

=head2 validate

  @errors = $self->validate($data);
  @errors = $self->validate($data, $schema);

Validates C<$data> against a given JSON L</schema>. C<@errors> will
contain validation error objects or be an empty list on success.

See L</ERROR OBJECT> for details.

C<$schema> is optional, but when specified, it will override schema stored in
L</schema>. Example:

  $self->validate({hero => "superwoman"}, {type => "object"});

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014-2015, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

Daniel Böhmer - C<post@daniel-boehmer.de>

Martin Renvoize - C<martin.renvoize@gmail.com>

=cut
