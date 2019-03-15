package JSON::Validator;
use Mojo::Base -base;

use B;
use Carp 'confess';
use Exporter 'import';
use JSON::Validator::Error;
use JSON::Validator::Formats;
use JSON::Validator::Joi;
use JSON::Validator::Ref;
use Mojo::File 'path';
use Mojo::JSON::Pointer;
use Mojo::JSON;
use Mojo::Loader;
use Mojo::URL;
use Mojo::Util qw(url_unescape sha1_sum);
use Scalar::Util qw(blessed refaddr);
use Time::Local ();

use constant CASE_TOLERANT     => File::Spec->case_tolerant;
use constant COLORS            => eval { require Term::ANSIColor };
use constant DEBUG             => $ENV{JSON_VALIDATOR_DEBUG} || 0;
use constant REPORT            => $ENV{JSON_VALIDATOR_REPORT} // DEBUG >= 2;
use constant RECURSION_LIMIT   => $ENV{JSON_VALIDATOR_RECURSION_LIMIT} || 100;
use constant SPECIFICATION_URL => 'http://json-schema.org/draft-04/schema#';

our $VERSION   = '3.06';
our @EXPORT_OK = qw(joi validate_json);

my $BUNDLED_CACHE_DIR = path(path(__FILE__)->dirname, qw(Validator cache));
my $HTTP_SCHEME_RE    = qr{^https?:};

sub D {
  Data::Dumper->new([@_])->Sortkeys(1)->Indent(0)->Maxdepth(2)->Pair(':')
    ->Useqq(1)->Terse(1)->Dump;
}
sub E { JSON::Validator::Error->new(@_) }

sub S {
  Mojo::Util::md5_sum(Data::Dumper->new([@_])->Sortkeys(1)->Useqq(1)->Dump);
}

has cache_paths => sub {
  return [split(/:/, $ENV{JSON_VALIDATOR_CACHE_PATH} || ''),
    $BUNDLED_CACHE_DIR];
};

has formats => sub { shift->_build_formats };
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
  my @topics = ([undef, my $bundle = {}]);
  my ($cloner, $tied);

  $topics[0][0]
    = $args->{schema} ? $self->_resolve($args->{schema}) : $self->schema->data;

  if ($args->{replace}) {
    $cloner = sub {
      my $from = shift;
      my $ref  = ref $from;
      $from = $tied->schema if $ref eq 'HASH' and $tied = tied %$from;
      my $to = $ref eq 'ARRAY' ? [] : $ref eq 'HASH' ? {} : $from;
      push @topics, [$from, $to] if $ref;
      return $to;
    };
  }
  else {
    my $ref_key = $args->{ref_key} || 'x-bundled';
    $bundle->{$ref_key} = $topics[0][0]{$ref_key} || {};
    $cloner = sub {
      my $from = shift;
      my $ref  = ref $from;

      if ($ref eq 'HASH' and my $tied = tied %$from) {
        my $ref_name = $tied->fqn;
        return $from if $ref_name =~ m!^\Q$self->{root_schema_url}\E\#!;

        if (-e $ref_name) {
          $ref_name = sprintf '%s-%s', substr(sha1_sum($ref_name), 0, 10),
            path($ref_name)->basename;
        }
        else {
          $ref_name =~ s![^\w-]!_!g;
        }

        push @topics, [$tied->schema, $bundle->{$ref_key}{$ref_name} = {}];
        tie my %ref, 'JSON::Validator::Ref', $tied->schema,
          "#/$ref_key/$ref_name";
        return \%ref;
      }

      my $to = $ref eq 'ARRAY' ? [] : $ref eq 'HASH' ? {} : $from;
      push @topics, [$from, $to] if $ref;
      return $to;
    };
  }

  while (@topics) {
    my ($from, $to) = @{shift @topics};
    if (ref $from eq 'ARRAY') {
      for (my $i = 0; $i < @$from; $i++) {
        $to->[$i] = $cloner->($from->[$i]);
      }
    }
    elsif (ref $from eq 'HASH') {
      while (my ($key, $value) = each %$from) {
        $to->{$key} //= $cloner->($from->{$key});
      }
    }
  }

  return $bundle;
}

sub coerce {
  my $self = shift;
  return $self->{coerce} ||= {} unless @_;
  $self->{coerce}
    = $_[0] eq '1' ? {booleans => 1, numbers => 1, strings => 1}
    : ref $_[0]    ? {%{$_[0]}}
    :                {@_};
  $self;
}

sub get {
  my ($self, $pointer) = @_;
  $pointer
    = [
      ref $pointer ? @$pointer
    : length $pointer ? split('/', $pointer, -1)
    :                   $pointer
    ];
  shift @$pointer
    if @$pointer
    and defined $pointer->[0]
    and !length $pointer->[0];
  $self->_get($self->schema->data, $pointer, '');
}

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

sub schema {
  my $self = shift;
  return $self->{schema} unless @_;
  $self->{schema} = Mojo::JSON::Pointer->new($self->_resolve(shift));
  return $self;
}

sub singleton { state $validator = shift->new }

sub validate {
  my ($self, $data, $schema) = @_;
  $schema ||= $self->schema->data;
  return E '/', 'No validation rules defined.' unless $schema and %$schema;

  local $self->{grouped} = 0;
  local $self->{schema}  = Mojo::JSON::Pointer->new($schema);
  local $self->{seen}    = {};
  local $self->{temp_schema} = [];    # make sure random-errors.t does not fail
  $self->{report} = [];
  my @errors = $self->_validate($_[1], '', $schema);
  $self->_report if DEBUG and REPORT;
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

sub _get {
  my ($self, $data, $path, $pos, $cb) = @_;
  my $tied;

  while (@$path) {
    my $p = shift @$path;

    unless (defined $p) {
      my $i = 0;
      return Mojo::Collection->new(
        map { $self->_get($_->[0], [@$path], _path($pos, $_->[1]), $cb) }
          ref $data eq 'ARRAY' ? map { [$_, $i++] }
          @$data : ref $data eq 'HASH' ? map { [$data->{$_}, $_] }
          sort keys %$data : [$data, '']);
    }

    $p =~ s!~1!/!g;
    $p =~ s/~0/~/g;
    $pos = _path($pos, $p) if $cb;

    if (ref $data eq 'HASH' and exists $data->{$p}) {
      $data = $data->{$p};
    }
    elsif (ref $data eq 'ARRAY' and $p =~ /^\d+$/ and @$data > $p) {
      $data = $data->[$p];
    }
    else {
      return undef;
    }

    $data = $tied->schema if ref $data eq 'HASH' and $tied = tied %$data;
  }

  return $cb->($data, $pos) if $cb;
  return $data;
}

sub _id_key { $_[0]->version < 7 ? 'id' : '$id' }

sub _load_schema {
  my ($self, $url) = @_;

  if ($url =~ m!^https?://!) {
    warn "[JSON::Validator] Loading schema from URL $url\n" if DEBUG;
    return $self->_load_schema_from_url(Mojo::URL->new($url)->fragment(undef)),
      "$url";
  }

  if ($url =~ m!^data://([^/]*)/(.*)!) {
    my ($file, @modules) = ($2, ($1));
    @modules = _stack() unless $modules[0];
    for my $module (@modules) {
      warn "[JSON::Validator] Looking for $file in $module\n" if DEBUG;
      my $text = Mojo::Loader::data_section($module, $file);
      return $self->_load_schema_from_text(\$text), "$url" if $text;
    }
    confess "$file could not be found in __DATA__ section of @modules.";
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
  my $visit;

  # JSON
  return Mojo::JSON::decode_json($$text) if $$text =~ /^\s*\{/s;

  # YAML
  $visit = sub {
    my $v = shift;
    $visit->($_) for grep { ref $_ eq 'HASH' } values %$v;
    return $v
      unless $v->{type}
      and $v->{type} eq 'boolean'
      and exists $v->{default};
    %$v
      = (%$v, default => $v->{default} ? Mojo::JSON->true : Mojo::JSON->false);
    return $v;
  };

  local $YAML::XS::Boolean = 'JSON::PP';
  return $visit->($self->_yaml_module->can('Load')->($$text));
}

sub _load_schema_from_url {
  my ($self, $url) = @_;
  my $cache_path = $self->cache_paths->[0];
  my $cache_file = Mojo::Util::md5_sum("$url");
  my ($err, $tx);

  for (@{$self->cache_paths}) {
    my $path = path $_, $cache_file;
    warn "[JSON::Validator] Looking for cached spec $path ($url)\n" if DEBUG;
    next unless -r $path;
    return $self->_load_schema_from_text(\$path->slurp);
  }

  $tx  = $self->ua->get($url);
  $err = $tx->error && $tx->error->{message};
  confess "GET $url == $err" if DEBUG and $err;
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

sub _ref_to_schema {
  my ($self, $schema) = @_;

  my @guard;
  while (my $tied = tied %$schema) {
    push @guard, $tied->ref;
    confess "Seems like you have a circular reference: @guard"
      if @guard > RECURSION_LIMIT;
    $schema = $tied->schema;
  }

  return $schema;
}

sub _register_schema {
  my ($self, $schema, $fqn) = @_;
  $fqn =~ s!(.)#$!$1!;
  $self->{schemas}{$fqn} = $schema;
}

sub _report {
  my $table = Mojo::Util::tablify($_[0]->{report});
  $table =~ s!^(\W*)(N?OK|<<<)(.*)!{
    my ($x, $y, $z) = ($1, $2, $3);
    my $c = $y eq 'OK' ? 'green' : $y eq '<<<' ? 'blue' : 'magenta';
    $c = "$c bold" if $z =~ /\s\w+Of\s/;
    Term::ANSIColor::colored([$c], "$x$y$z")
  }!gme if COLORS;
  warn "---\n$table";
}

sub _report_errors {
  my ($self, $path, $type, $errors) = @_;
  push @{$self->{report}},
    [
    (('  ') x $self->{grouped}) . (@$errors ? 'NOK' : 'OK'),
    $path || '/',
    $type, join "\n", @$errors
    ];
}

sub _report_schema {
  my ($self, $path, $type, $schema) = @_;
  push @{$self->{report}},
    [(('  ') x $self->{grouped}) . ('<<<'), $path || '/', $type, D $schema];
}

# _resolve() method is used to convert all "id" into absolute URLs and
# resolve all the $ref's that we find inside JSON Schema specification.
sub _resolve {
  my ($self, $schema) = @_;
  my $id_key = $self->_id_key;
  my ($id, $resolved, @refs);

  local $self->{level} = $self->{level} || 0;
  delete $_[0]->{schemas}{''} unless $self->{level};

  if (ref $schema eq 'HASH') {
    $id = $schema->{$id_key} // '';
    return $resolved if $resolved = $self->{schemas}{$id};
  }
  elsif ($resolved = $self->{schemas}{$schema // ''}) {
    return $resolved;
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

  my @topics
    = ([$schema, UNIVERSAL::isa($id, 'Mojo::File') ? $id : Mojo::URL->new($id)
    ]);
  while (@topics) {
    my ($topic, $base) = @{shift @topics};

    if (UNIVERSAL::isa($topic, 'ARRAY')) {
      push @topics, map { [$_, $base] } @$topic;
    }
    elsif (UNIVERSAL::isa($topic, 'HASH')) {
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
  if ($base->isa('Mojo::File')) {
    return $base if !length $location;
    return $base->sibling(split '/', $location)->realpath;
  }
  return $location_as_url->to_abs($base);
}

sub _resolve_ref {
  my ($self, $topic, $url) = @_;
  return if tied %$topic;

  my $other = $topic;
  my ($location, $fqn, $pointer, $ref, @guard);

  while (1) {
    $ref = $other->{'$ref'};
    push @guard, $other->{'$ref'};
    confess "Seems like you have a circular reference: @guard"
      if @guard > RECURSION_LIMIT;
    last if !$ref or ref $ref;
    $fqn = $ref =~ m!^/! ? "#$ref" : $ref;
    ($location, $pointer) = split /#/, $fqn, 2;
    $url = $location = _location_to_abs($location, $url);
    $pointer = undef if length $location and !length $pointer;
    $pointer = url_unescape $pointer if defined $pointer;
    $fqn   = join '#', grep defined, $location, $pointer;
    $other = $self->_resolve($location);

    if (defined $pointer and length $pointer and $pointer =~ m!^/!) {
      $other = Mojo::JSON::Pointer->new($other)->get($pointer)
        or confess
        qq[Possibly a typo in schema? Could not find "$pointer" in "$location" ($ref)];
    }
  }

  tie %$topic, 'JSON::Validator::Ref', $other, $topic->{'$ref'}, $fqn;
}

sub _stack {
  my @classes;
  my $i = 2;
  while (my $pkg = caller($i++)) {
    no strict 'refs';
    push @classes,
      grep { !/(^JSON::Validator$|^Mojo::Base$|^Mojolicious$|\w+::_Dynamic)/ }
      $pkg, @{"$pkg\::ISA"};
  }
  return @classes;
}

sub _validate {
  my ($self, $data, $path, $schema) = @_;
  my ($seen_addr, $to_json, $type);

  # Do not validate against "default" in draft-07 schema
  return if blessed $schema and $schema->isa('JSON::PP::Boolean');

  $schema    = $self->_ref_to_schema($schema) if $schema->{'$ref'};
  $seen_addr = join ':', refaddr($schema),
    (ref $data ? refaddr $data : ++$self->{seen}{scalar});

  # Avoid recursion
  if ($self->{seen}{$seen_addr}) {
    $self->_report_schema($path || '/', 'seen', $schema) if REPORT;
    return @{$self->{seen}{$seen_addr}};
  }

  $self->{seen}{$seen_addr} = \my @errors;
  $to_json
    = (blessed $data and $data->can('TO_JSON')) ? \$data->TO_JSON : undef;
  $data = $$to_json if $to_json;
  $type = $schema->{type} || _guess_schema_type($schema, $data);

  # Test base schema before allOf, anyOf or oneOf
  if (ref $type eq 'ARRAY') {
    push @{$self->{temp_schema}}, [map { +{%$schema, type => $_} } @$type];
    push @errors,
      $self->_validate_any_of($to_json ? $$to_json : $_[1],
      $path, $self->{temp_schema}[-1]);
  }
  elsif ($type) {
    my $method = sprintf '_validate_type_%s', $type;
    $self->_report_schema($path || '/', $type, $schema);
    @errors = $self->$method($to_json ? $$to_json : $_[1], $path, $schema);
    $self->_report_errors($path, $type, \@errors) if REPORT;
    return @errors if @errors;
  }

  if ($schema->{enum}) {
    push @errors,
      $self->_validate_type_enum($to_json ? $$to_json : $_[1], $path, $schema);
    $self->_report_errors($path, 'enum', \@errors) if REPORT;
    return @errors if @errors;
  }

  if (my $rules = $schema->{not}) {
    push @errors, $self->_validate($to_json ? $$to_json : $_[1], $path, $rules);
    $self->_report_errors($path, 'not', \@errors) if REPORT;
    return @errors ? () : (E $path, 'Should not match.');
  }

  if (my $rules = $schema->{allOf}) {
    push @errors,
      $self->_validate_all_of($to_json ? $$to_json : $_[1], $path, $rules);
  }
  elsif ($rules = $schema->{anyOf}) {
    push @errors,
      $self->_validate_any_of($to_json ? $$to_json : $_[1], $path, $rules);
  }
  elsif ($rules = $schema->{oneOf}) {
    push @errors,
      $self->_validate_one_of($to_json ? $$to_json : $_[1], $path, $rules);
  }

  return @errors;
}

sub _validate_all_of {
  my ($self, $data, $path, $rules) = @_;
  my $type = _guess_data_type($data, $rules);
  my (@errors, @expected);

  $self->_report_schema($path, 'allOf', $rules) if REPORT;
  local $self->{grouped} = $self->{grouped} + 1;

  my $i = 0;
  for my $rule (@$rules) {
    next unless my @e = $self->_validate($_[1], $path, $rule);
    my $schema_type = _guess_schema_type($rule);
    push @expected, $schema_type if $schema_type;
    push @errors, [$i, @e] if !$schema_type or $schema_type eq $type;
  }
  continue {
    $i++;
  }

  $self->_report_errors($path, 'allOf', \@errors) if REPORT;
  return E $path, "/allOf Expected @{[join '/', _uniq(@expected)]} - got $type."
    if !@errors and @expected;
  return _add_path_to_error_messages(allOf => @errors) if @errors;
  return;
}

sub _validate_any_of {
  my ($self, $data, $path, $rules) = @_;
  my $type = _guess_data_type($data, $rules);
  my (@e, @errors, @expected);

  $self->_report_schema($path, 'anyOf', $rules) if REPORT;
  local $self->{grouped} = $self->{grouped} + 1;

  my $i = 0;
  for my $rule (@$rules) {
    @e = $self->_validate($_[1], $path, $rule);
    return unless @e;
    my $schema_type = _guess_schema_type($rule);
    push @errors, [$i, @e] and next if !$schema_type or $schema_type eq $type;
    push @expected, $schema_type;
  }
  continue {
    $i++;
  }

  $self->_report_errors($path, 'anyOf', \@errors) if REPORT;
  my $expected = join '/', _uniq(@expected);
  return E $path, "/anyOf Expected $expected - got $type." unless @errors;
  return _add_path_to_error_messages(anyOf => @errors);
}

sub _validate_one_of {
  my ($self, $data, $path, $rules) = @_;
  my $type = _guess_data_type($data, $rules);
  my (@errors, @expected);

  $self->_report_schema($path, 'oneOf', $rules) if REPORT;
  local $self->{grouped} = $self->{grouped} + 1;

  my $i = 0;
  for my $rule (@$rules) {
    my @e           = $self->_validate($_[1], $path, $rule) or next;
    my $schema_type = _guess_schema_type($rule);
    push @errors, [$i, @e] and next if !$schema_type or $schema_type eq $type;
    push @expected, $schema_type;
  }
  continue {
    $i++;
  }

  if (REPORT) {
    my @e
      = @errors + @expected + 1 == @$rules ? ()
      : @errors                            ? @errors
      :                                      'All of the oneOf rules match.';
    $self->_report_errors($path, 'oneOf', \@e);
  }

  return if @errors + @expected + 1 == @$rules;
  my $expected = join '/', _uniq(@expected);
  return E $path, "All of the oneOf rules match." unless @errors + @expected;
  return E $path, "/oneOf Expected $expected - got $type." unless @errors;
  return _add_path_to_error_messages(oneOf => @errors);
}

sub _validate_type_enum {
  my ($self, $data, $path, $schema) = @_;
  my $enum = $schema->{enum};
  my $m    = S $data;

  for my $i (@$enum) {
    return if $m eq S $i;
  }

  local $" = ', ';
  return E $path, sprintf 'Not in enum list: %s.', join ', ',
    map { (!defined or ref) ? Mojo::JSON::encode_json($_) : $_ } @$enum;
}

sub _validate_type_const {
  my ($self, $data, $path, $schema) = @_;
  my $const = $schema->{const};
  my $m     = S $data;

  return if $m eq S $const;
  return E $path, sprintf 'Does not match const: %s.',
    Mojo::JSON::encode_json($const);
}

sub _validate_format {
  my ($self, $value, $path, $schema) = @_;
  my $code = $self->formats->{$schema->{format}};
  return do { warn "Format rule for '$schema->{format}' is missing"; return }
    unless $code;
  return unless my $err = $code->($value);
  return E $path, $err;
}

sub _validate_type_any { }

sub _validate_type_array {
  my ($self, $data, $path, $schema) = @_;
  my @errors;

  if (ref $data ne 'ARRAY') {
    return E $path, _expected(array => $data);
  }
  if (defined $schema->{minItems} and $schema->{minItems} > @$data) {
    push @errors, E $path, sprintf 'Not enough items: %s/%s.', int @$data,
      $schema->{minItems};
  }
  if (defined $schema->{maxItems} and $schema->{maxItems} < @$data) {
    push @errors, E $path, sprintf 'Too many items: %s/%s.', int @$data,
      $schema->{maxItems};
  }
  if ($schema->{uniqueItems}) {
    my %uniq;
    for (@$data) {
      next if !$uniq{S($_)}++;
      push @errors, E $path, 'Unique items required.';
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
      push @errors, E $path, sprintf "Invalid number of items: %s/%s.",
        int(@$data), int(@rules);
    }
  }
  elsif (UNIVERSAL::isa($schema->{items}, 'HASH')) {
    for my $i (0 .. @$data - 1) {
      push @errors, $self->_validate($data->[$i], "$path/$i", $schema->{items});
    }
  }

  return @errors;
}

sub _validate_type_boolean {
  my ($self, $value, $path, $schema) = @_;

  # Object representing a boolean
  if (blessed $value
    and ($value->isa('JSON::PP::Boolean') or "$value" eq "1" or !$value))
  {
    return;
  }

  # String that looks like a boolean
  if (
        defined $value
    and $self->{coerce}{booleans}
    and (B::svref_2object(\$value)->FLAGS & (B::SVp_IOK | B::SVp_NOK)
      or $value =~ /^(true|false)$/)
    )
  {
    $_[1] = $value ? Mojo::JSON->true : Mojo::JSON->false;
    return;
  }

  return E $path, _expected(boolean => $value);
}

sub _validate_type_integer {
  my ($self, $value, $path, $schema) = @_;
  my @errors = $self->_validate_type_number($_[1], $path, $schema, 'integer');

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
  unless (_is_number($value)) {
    return E $path, "Expected $expected - got string."
      if !$self->{coerce}{numbers}
      or $value !~ /^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?$/;
    $_[1] = 0 + $value;    # coerce input value
  }

  if ($schema->{format}) {
    push @errors, $self->_validate_format($value, $path, $schema);
  }
  if (my $e
    = _cmp($schema->{minimum}, $value, $schema->{exclusiveMinimum}, '<'))
  {
    push @errors, E $path, "$value $e minimum($schema->{minimum})";
  }
  if (my $e
    = _cmp($value, $schema->{maximum}, $schema->{exclusiveMaximum}, '>'))
  {
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

  my @dkeys = sort keys %$data;
  if (defined $schema->{maxProperties} and $schema->{maxProperties} < @dkeys) {
    push @errors, E $path, sprintf 'Too many properties: %s/%s.', int @dkeys,
      $schema->{maxProperties};
  }
  if (defined $schema->{minProperties} and $schema->{minProperties} > @dkeys) {
    push @errors, E $path, sprintf 'Not enough properties: %s/%s.', int @dkeys,
      $schema->{minProperties};
  }
  if (my $n_schema = $schema->{propertyNames}) {
    for my $name (keys %$data) {
      next unless my @e = $self->_validate($name, $path, $n_schema);
      push @errors,
        _add_path_to_error_messages(propertyName => [map { ($name, $_) } @e]);
    }
  }
  if ($schema->{if}) {
    push @errors,
      $self->_validate($data, $path, $schema->{if})
      ? $self->_validate($data, $path, $schema->{else} // {})
      : $self->_validate($data, $path, $schema->{then} // {});
  }

  while (my ($k, $r) = each %{$schema->{properties}}) {
    push @{$rules{$k}}, $r;
  }
  while (my ($p, $r) = each %{$schema->{patternProperties} || {}}) {
    push @{$rules{$_}}, $r for sort grep { $_ =~ /$p/ } @dkeys;
  }

  $additional
    = exists $schema->{additionalProperties}
    ? $schema->{additionalProperties}
    : {};
  if ($additional) {
    $additional = {} unless UNIVERSAL::isa($additional, 'HASH');
    $rules{$_} ||= [$additional] for @dkeys;
  }
  elsif (my @k = grep { !$rules{$_} } @dkeys) {
    local $" = ', ';
    return E $path, "Properties not allowed: @k.";
  }

  for my $k (sort keys %required) {
    next if exists $data->{$k};
    push @errors, E _path($path, $k), 'Missing property.';
    delete $rules{$k};
  }

  for my $k (sort keys %rules) {
    for my $r (@{$rules{$k}}) {
      next unless exists $data->{$k};
      my @e = $self->_validate($data->{$k}, _path($path, $k), $r);
      push @errors, @e;
      next if @e or !UNIVERSAL::isa($r, 'HASH');
      push @errors,
        $self->_validate_type_enum($data->{$k}, _path($path, $k), $r)
        if $r->{enum};
      push @errors,
        $self->_validate_type_const($data->{$k}, _path($path, $k), $r)
        if $r->{const};
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
    return E $path, "Expected string - got number."
      unless $self->{coerce}{strings};
    $_[1] = "$value";    # coerce input value
  }
  if ($schema->{format}) {
    push @errors, $self->_validate_format($value, $path, $schema);
  }
  if (defined $schema->{maxLength}) {
    if (length($value) > $schema->{maxLength}) {
      push @errors, E $path, sprintf "String is too long: %s/%s.",
        length($value), $schema->{maxLength};
    }
  }
  if (defined $schema->{minLength}) {
    if (length($value) < $schema->{minLength}) {
      push @errors, E $path, sprintf "String is too short: %s/%s.",
        length($value), $schema->{minLength};
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

sub _add_path_to_error_messages {
  my ($type, @errors_with_index) = @_;
  my @errors;

  for my $e (@errors_with_index) {
    my $index = shift @$e;
    push @errors, map {
      my $msg = sprintf '/%s/%s %s', $type, $index, $_->{message};
      $msg =~ s!(\d+)\s/!$1/!g;
      E $_->path, $msg;
    } @$e;
  }

  return @errors;
}

sub _cmp {
  return undef if !defined $_[0] or !defined $_[1];
  return "$_[3]=" if $_[2] and $_[0] >= $_[1];
  return $_[3] if $_[0] > $_[1];
  return "";
}

sub _expected {
  my $type = _guess_data_type($_[1], []);
  return "Expected $_[0] - got different $type." if $_[0] =~ /\b$type\b/;
  return "Expected $_[0] - got $type.";
}

# _guess_data_type($data, [{type => ...}, ...])
sub _guess_data_type {
  my $ref     = ref $_[0];
  my $blessed = blessed $_[0];
  return 'object' if $ref eq 'HASH';
  return lc $ref if $ref and !$blessed;
  return 'null' if !defined $_[0];
  return 'boolean' if $blessed and ("$_[0]" eq "1" or !"$_[0]");

  if (_is_number($_[0])) {
    return 'integer' if grep { ($_->{type} // '') eq 'integer' } @{$_[1] || []};
    return 'number';
  }

  return $blessed || 'string';
}

# _guess_schema_type($schema, $data)
sub _guess_schema_type {
  return $_[0]->{type} if $_[0]->{type};
  return _guessed_right(object => $_[1]) if $_[0]->{additionalProperties};
  return _guessed_right(object => $_[1]) if $_[0]->{patternProperties};
  return _guessed_right(object => $_[1]) if $_[0]->{properties};
  return _guessed_right(object => $_[1]) if $_[0]->{propertyNames};
  return _guessed_right(object => $_[1]) if $_[0]->{required};
  return _guessed_right(object => $_[1]) if $_[0]->{if};
  return _guessed_right(object => $_[1])
    if defined $_[0]->{maxProperties}
    or defined $_[0]->{minProperties};
  return _guessed_right(array => $_[1]) if $_[0]->{additionalItems};
  return _guessed_right(array => $_[1]) if $_[0]->{items};
  return _guessed_right(array => $_[1]) if $_[0]->{uniqueItems};
  return _guessed_right(array => $_[1])
    if defined $_[0]->{maxItems}
    or defined $_[0]->{minItems};
  return _guessed_right(string => $_[1]) if $_[0]->{pattern};
  return _guessed_right(string => $_[1])
    if defined $_[0]->{maxLength}
    or defined $_[0]->{minLength};
  return _guessed_right(number => $_[1]) if $_[0]->{multipleOf};
  return _guessed_right(number => $_[1])
    if defined $_[0]->{maximum}
    or defined $_[0]->{minimum};
  return 'const' if $_[0]->{const};
  return undef;
}

# _guessed_right($type, $data);
sub _guessed_right {
  return $_[0] if !defined $_[1];
  return $_[0] if $_[0] eq _guess_data_type($_[1], [{type => $_[0]}]);
  return undef;
}

sub _is_number {
  B::svref_2object(\$_[0])->FLAGS & (B::SVp_IOK | B::SVp_NOK)
    && 0 + $_[0] eq $_[0]
    && $_[0] * 0 == 0;
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
  state $yaml_module = eval qq[use YAML::XS 0.67; "YAML::XS"]
    || die
    "[JSON::Validator] The optional YAML::XS module is missing or could not be loaded: $@";
}

1;

=encoding utf8

=head1 NAME

JSON::Validator - Validate data against a JSON schema

=head1 SYNOPSIS

  use JSON::Validator;
  my $validator = JSON::Validator->new;

  # Define a schema - http://json-schema.org/learn/miscellaneous-examples.html
  # You can also load schema from disk or web
  $validator->schema({
    type       => "object",
    required   => ["firstName", "lastName"],
    properties => {
      firstName => {type => "string"},
      lastName  => {type => "string"},
      age       => {type => "integer", minimum => 0, description => "Age in years"}
    }
  });

  # Validate your data
  my @errors = $validator->validate({firstName => "Jan Henning", lastName => "Thorsen", age => -42});

  # Do something if any errors was found
  die "@errors" if @errors;

  # Use joi() to build the schema
  use JSON::Validator 'joi';

  $validator->schema(joi->object->props({
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
L<JSON::Validator::joi> to define the schema programmatically.

=head2 Supported schema formats

L<JSON::Validator> can load JSON schemas in multiple formats: Plain perl data
structured (as shown in L</SYNOPSIS>), JSON or YAML. The JSON parsing is done
with L<Mojo::JSON>, while YAML files require the optional module L<YAML::XS> to
be installed.

=head2 Resources

Here are some resources that are related to JSON schemas and validation:

=over 4

=item * L<http://json-schema.org/documentation.html>

=item * L<http://spacetelescope.github.io/understanding-json-schema/index.html>

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

C<$ref>: L<http://swagger.io/v3/schema.yaml#>

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

  my $validator = $validator->cache_paths(\@paths);
  my $array_ref = $validator->cache_paths;

A list of directories to where cached specifications are stored. Defaults to
C<JSON_VALIDATOR_CACHE_PATH> environment variable and the specs that is bundled
with this distribution.

C<JSON_VALIDATOR_CACHE_PATH> can be a list of directories, each separated by ":".

See L</Bundled specifications> for more details.

=head2 formats

  my $hash_ref  = $validator->formats;
  my $validator = $validator->formats(\%hash);

Holds a hash-ref, where the keys are supported JSON type "formats", and
the values holds a code block which can validate a given format. A code
block should return C<undef> on success and an error string on error:

  sub { return defined $_[0] && $_[0] eq "42" ? undef : "Not the answer." };

See L<JSON::Validator::Formats> for a list of supported formats.

=head2 ua

  my $ua        = $validator->ua;
  my $validator = $validator->ua(Mojo::UserAgent->new);

Holds a L<Mojo::UserAgent> object, used by L</schema> to load a JSON schema
from remote location.

The default L<Mojo::UserAgent> will detect proxy settings and have
L<Mojo::UserAgent/max_redirects> set to 3.

=head2 version

  my $int       = $validator->version;
  my $validator = $validator->version(7);

Used to set the JSON Schema version to use. Will be set automatically when
using L</load_and_validate_schema>, unless already set.

=head1 METHODS

=head2 bundle

  my $schema = $validator->bundle(\%args);

Used to create a new schema, where the C<$ref> are resolved. C<%args> can have:

=over 2

=item * C<< {replace => 1} >>

Used if you want to replace the C<$ref> inline in the schema. This currently
does not work if you have circular references. The default is to move all the
C<$ref> definitions into the main schema with custom names. Here is an example
on how a C<$ref> looks before and after:

  {"$ref":"../some/place.json#/foo/bar"}
     => {"$ref":"#/definitions/____some_place_json-_foo_bar"}

  {"$ref":"http://example.com#/foo/bar"}
     => {"$ref":"#/definitions/_http___example_com-_foo_bar"}

=item * C<< {schema => {...}} >>

Default is to use the value from the L</schema> attribute.

=back

=head2 coerce

  my $validator = $validator->coerce(booleans => 1, numbers => 1, strings => 1);
  my $validator = $validator->coerce({booleans => 1, numbers => 1, strings => 1});
  my $hash_ref  = $validator->coerce;

Set the given type to coerce. Before enabling coercion this module is very
strict when it comes to validating types. Example: The string C<"1"> is not
the same as the number C<1>, unless you have coercion enabled.

Loading a YAML document will enable "booleans" automatically. This feature is
experimental, but was added since YAML has no real concept of booleans, such
as L<Mojo::JSON> or other JSON parsers.

=head2 get

  my $sub_schema = $validator->get("/x/y");
  my $sub_schema = $validator->get(["x", "y"]);

Extract value from L</schema> identified by the given JSON Pointer. Will at the
same time resolve C<$ref> if found. Example:

  $validator->schema({x => {'$ref' => '#/y'}, y => {'type' => 'string'}});
  $validator->schema->get('/x')           == undef
  $validator->schema->get('/x')->{'$ref'} == '#/y'
  $validator->get('/x')                   == {type => 'string'}

The argument can also be an array-ref with the different parts of the pointer
as each elements.

=head2 load_and_validate_schema

  my $validator = $validator->load_and_validate_schema($schema, \%args);

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

  my $validator = $validator->schema($json_or_yaml_string);
  my $validator = $validator->schema($url);
  my $validator = $validator->schema(\%schema);
  my $validator = $validator->schema(JSON::Validator::Joi->new);
  my $schema    = $validator->schema;

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
L<Mojo::Loader/data_section>.

=item * data:///spec.json

A "data" URL without a module name will use the current package and search up
the call/inheritance tree.

=item * Any other URL

An URL (without a recognized scheme) will be treated as a path to a file on
disk.

=back

=head2 singleton

  my $validator = JSON::Validator->singleton;

Returns the L<JSON::Validator> object used by L</validate_json>.

=head2 validate

  my @errors = $validator->validate($data);
  my @errors = $validator->validate($data, $schema);

Validates C<$data> against a given JSON L</schema>. C<@errors> will
contain validation error objects or be an empty list on success.

See L</ERROR OBJECT> for details.

C<$schema> is optional, but when specified, it will override schema stored in
L</schema>. Example:

  $validator->validate({hero => "superwoman"}, {type => "object"});

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

Kevin Goess - C<cpan@goess.org>

Martin Renvoize - C<martin.renvoize@gmail.com>

=cut
