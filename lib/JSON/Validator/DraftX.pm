package JSON::Validator::DraftX;
use Mojo::Base 'JSON::Validator';

use B;
use JSON::Validator::Util
  qw(E add_path_to_error_messages guess_data_type guess_schema_type is_number is_boolean json_path uniq);
use Mojo::JSON qw(false true);
use Scalar::Util qw(blessed refaddr);

use constant DEBUG  => $ENV{JSON_VALIDATOR_DEBUG} || 0;
use constant REPORT => $ENV{JSON_VALIDATOR_REPORT} // DEBUG >= 2;

sub S {
  Mojo::Util::md5_sum(Data::Dumper->new([@_])->Sortkeys(1)->Useqq(1)->Dump);
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
  $type = $schema->{type} || guess_schema_type $schema, $data;

  # Test base schema before allOf, anyOf or oneOf
  if (ref $type eq 'ARRAY') {
    push @{$self->{temp_schema}}, [map { +{%$schema, type => $_} } @$type];
    push @errors,
      $self->_validate_any_of($to_json ? $$to_json : $_[1],
      $path, $self->{temp_schema}[-1]);
  }
  elsif ($type) {
    my $method = sprintf '_validate_type_%s', $type;
    $self->_report_schema($path || '/', $type, $schema) if REPORT;
    @errors = $self->$method($to_json ? $$to_json : $_[1], $path, $schema);
    $self->_report_errors($path, $type, \@errors) if REPORT;
    return @errors                                if @errors;
  }

  if (exists $schema->{const}) {
    push @errors,
      $self->_validate_type_const($to_json ? $$to_json : $_[1], $path, $schema);
    $self->_report_errors($path, 'const', \@errors) if REPORT;
    return @errors                                  if @errors;
  }

  if ($schema->{enum}) {
    push @errors,
      $self->_validate_type_enum($to_json ? $$to_json : $_[1], $path, $schema);
    $self->_report_errors($path, 'enum', \@errors) if REPORT;
    return @errors                                 if @errors;
  }

  if (my $rules = $schema->{not}) {
    push @errors, $self->_validate($to_json ? $$to_json : $_[1], $path, $rules);
    $self->_report_errors($path, 'not', \@errors) if REPORT;
    return @errors ? () : (E $path, [not => 'not']);
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
  my $type = guess_data_type $data, $rules;
  my (@errors, @expected);

  $self->_report_schema($path, 'allOf', $rules) if REPORT;
  local $self->{grouped} = $self->{grouped} + 1;

  my $i = 0;
  for my $rule (@$rules) {
    next unless my @e = $self->_validate($_[1], $path, $rule);
    my $schema_type = guess_schema_type $rule;
    push @expected, $schema_type if $schema_type;
    push @errors, [$i, @e] if !$schema_type or $schema_type eq $type;
  }
  continue {
    $i++;
  }

  $self->_report_errors($path, 'allOf', \@errors) if REPORT;
  return E $path, [allOf => type => join('/', uniq @expected), $type]
    if !@errors and @expected;
  return add_path_to_error_messages allOf => @errors if @errors;
  return;
}

sub _validate_any_of {
  my ($self, $data, $path, $rules) = @_;
  my $type = guess_data_type $data, $rules;
  my (@e, @errors, @expected);

  $self->_report_schema($path, 'anyOf', $rules) if REPORT;
  local $self->{grouped} = $self->{grouped} + 1;

  my $i = 0;
  for my $rule (@$rules) {
    @e = $self->_validate($_[1], $path, $rule);
    return unless @e;
    my $schema_type = guess_schema_type $rule;
    push @errors, [$i, @e] and next if !$schema_type or $schema_type eq $type;
    push @expected, $schema_type;
  }
  continue {
    $i++;
  }

  $self->_report_errors($path, 'anyOf', \@errors) if REPORT;
  my $expected = join '/', uniq @expected;
  return E $path, [anyOf => type => $expected, $type] unless @errors;
  return add_path_to_error_messages anyOf => @errors;
}

sub _validate_one_of {
  my ($self, $data, $path, $rules) = @_;
  my $type = guess_data_type $data, $rules;
  my (@errors, @expected);

  $self->_report_schema($path, 'oneOf', $rules) if REPORT;
  local $self->{grouped} = $self->{grouped} + 1;

  my ($i, @passed) = (0);
  for my $rule (@$rules) {
    my @e = $self->_validate($_[1], $path, $rule) or push @passed, $i and next;
    my $schema_type = guess_schema_type $rule;
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

  return if @passed == 1;
  return E $path, [oneOf => 'all_rules_match'] unless @errors + @expected;
  return E $path, [oneOf => 'n_rules_match', join(', ', @passed)] if @passed;
  return add_path_to_error_messages oneOf => @errors if @errors;
  return E $path, [oneOf => type => join('/', uniq @expected), $type];
}

sub _validate_number_max {
  my ($self, $value, $path, $schema, $expected) = @_;
  my @errors;

  my $cmp_with = $schema->{exclusiveMaximum} // '';
  if (is_boolean $cmp_with) {
    push @errors, E $path,
      [$expected => ex_maximum => $value, $schema->{maximum}]
      unless $value < $schema->{maximum};
  }
  elsif (is_number $cmp_with) {
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
  if (is_boolean $cmp_with) {
    push @errors, E $path,
      [$expected => ex_minimum => $value, $schema->{minimum}]
      unless $value > $schema->{minimum};
  }
  elsif (is_number $cmp_with) {
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
  my $m    = S $data;

  for my $i (@$enum) {
    return if $m eq S $i;
  }

  $enum = join ', ',
    map { (!defined or ref) ? Mojo::JSON::encode_json($_) : $_ } @$enum;
  return E $path, [enum => enum => $enum];
}

sub _validate_type_const {
  my ($self, $data, $path, $schema) = @_;
  my $const = $schema->{const};
  my $m     = S $data;

  return if $m eq S $const;
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
    return E $path, [array => type => guess_data_type $data];
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
      next if !$uniq{S($_)}++;
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
  elsif (UNIVERSAL::isa($schema->{items}, 'HASH')) {
    for my $i (0 .. @$data - 1) {
      push @errors, $self->_validate($data->[$i], "$path/$i", $schema->{items});
    }
  }

  return @errors;
}

sub _validate_type_boolean {
  my ($self, $value, $path, $schema) = @_;
  return if is_boolean $value;

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

  return E $path, [boolean => type => guess_data_type $value];
}

sub _validate_type_integer {
  my ($self, $value, $path, $schema) = @_;
  my @errors = $self->_validate_type_number($_[1], $path, $schema, 'integer');

  return @errors if @errors;
  return         if $value =~ /^-?\d+$/;
  return E $path, [integer => type => guess_data_type $value];
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
    return E $path, [$expected => type => guess_data_type $value];
  }
  unless (is_number $value) {
    return E $path, [$expected => type => guess_data_type $value]
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
  my %required = map { ($_ => 1) } @{$schema->{required} || []};
  my ($additional, @errors, %rules);

  if (ref $data ne 'HASH') {
    return E $path, [object => type => guess_data_type $data];
  }

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
      push @errors,
        add_path_to_error_messages propertyName => [map { ($name, $_) } @e];
    }
  }
  if ($schema->{if}) {
    push @errors,
      $self->_validate($data, $path, $schema->{if})
      ? $self->_validate($data, $path, $schema->{else} // {})
      : $self->_validate($data, $path, $schema->{then} // {});
  }

  my $coerce_defaults = $self->{coerce}{defaults};
  while (my ($k, $r) = each %{$schema->{properties}}) {
    push @{$rules{$k}}, $r;
    next unless $coerce_defaults;
    $data->{$k} = $r->{default} if exists $r->{default} and !exists $data->{$k};
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
    return E $path, [object => additionalProperties => join '/', @k];
  }

  for my $k (sort keys %required) {
    next if exists $data->{$k};
    push @errors, E json_path($path, $k), [object => 'required'];
    delete $rules{$k};
  }

  for my $k (sort keys %rules) {
    for my $r (@{$rules{$k}}) {
      next unless exists $data->{$k};
      my @e = $self->_validate($data->{$k}, json_path($path, $k), $r);
      push @errors, @e;
      next if @e or !UNIVERSAL::isa($r, 'HASH');
      push @errors,
        $self->_validate_type_enum($data->{$k}, json_path($path, $k), $r)
        if $r->{enum};
      push @errors,
        $self->_validate_type_const($data->{$k}, json_path($path, $k), $r)
        if $r->{const};
    }
  }

  return @errors;
}

sub _validate_type_string {
  my ($self, $value, $path, $schema) = @_;
  my @errors;

  if (!defined $value or ref $value) {
    return E $path, [string => type => guess_data_type $value];
  }
  if (  B::svref_2object(\$value)->FLAGS & (B::SVp_IOK | B::SVp_NOK)
    and 0 + $value eq $value
    and $value * 0 == 0)
  {
    return E $path, [string => type => guess_data_type $value]
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
