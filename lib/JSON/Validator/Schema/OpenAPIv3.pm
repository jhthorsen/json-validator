package JSON::Validator::Schema::OpenAPIv3;
use Mojo::Base 'JSON::Validator::Schema::OpenAPIv2';

use JSON::Validator::Util qw(E schema_type);
use Mojo::JSON qw(false true);
use Mojo::Path;

has moniker       => 'openapiv3';
has specification => 'https://spec.openapis.org/oas/3.0/schema/2019-04-02';

sub parameters_for_request {
  my $self = shift;
  my ($method, $path) = (lc $_[0][0], $_[0][1]);

  my $cache_key = "parameters_for_request:$method:$path";
  return $self->{cache}{$cache_key} if $self->{cache}{$cache_key};
  return undef unless $self->get([paths => $path, $method]);

  my @parameters = map {@$_} $self->_find_all_nodes([paths => $path, $method], 'parameters');
  for my $param (@parameters) {
    $param->{type} ||= schema_type($param->{schema});
  }

  if (my $request_body = $self->get([paths => $path, $method, 'requestBody'])) {
    my @accepts = sort keys %{$request_body->{content} || {}};
    push @parameters,
      {
      accepts  => \@accepts,
      content  => $request_body->{content},
      in       => 'body',
      name     => 'body',
      required => $request_body->{required},
      };
  }

  return $self->{cache}{$cache_key} = \@parameters;
}

sub parameters_for_response {
  my $self = shift;
  my ($method, $path, $status) = (lc $_[0][0], $_[0][1], $_[0][2] || 200);

  $status ||= 200;
  my $cache_key = "parameters_for_response:$method:$path:$status";
  return $self->{cache}{$cache_key} if $self->{cache}{$cache_key};

  my $responses = $self->get([paths => $path, $method, 'responses']);
  my $response  = $responses->{$status} || $responses->{default};
  return undef unless $response;

  my @parameters;
  if (my $headers = $response->{headers}) {
    push @parameters, map { +{%{$headers->{$_}}, in => 'header', name => $_} } sort keys %$headers;
  }

  if (my @accepts = sort keys %{$response->{content} || {}}) {
    push @parameters, {accepts => \@accepts, content => $response->{content}, in => 'body', name => 'body'};
  }

  return $self->{cache}{$cache_key} = \@parameters;
}

sub _build_formats {

  # TODO: Figure out if this is the correct list
  return {
    'binary'                => sub {undef},
    'byte'                  => JSON::Validator::Formats->can('check_byte'),
    'date'                  => JSON::Validator::Formats->can('check_date'),
    'date-time'             => JSON::Validator::Formats->can('check_date_time'),
    'double'                => JSON::Validator::Formats->can('check_double'),
    'duration'              => JSON::Validator::Formats->can('check_duration'),
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
    'password'              => sub {undef},
    'regex'                 => JSON::Validator::Formats->can('check_regex'),
    'relative-json-pointer' => JSON::Validator::Formats->can('check_relative_json_pointer'),
    'time'                  => JSON::Validator::Formats->can('check_time'),
    'uri'                   => JSON::Validator::Formats->can('check_uri'),
    'uri-reference'         => JSON::Validator::Formats->can('check_uri_reference'),
    'uri-template'          => JSON::Validator::Formats->can('check_uri_template'),
    'uuid'                  => JSON::Validator::Formats->can('check_uuid'),
  };
}

sub _coerce_parameter_format {
  my ($self, $val, $param) = @_;
  return unless $val->{exists};

  state $in_style = {cookie => 'form', header => 'simple', path => 'simple', query => 'form'};
  $param->{style} = $in_style->{$param->{in}} unless $param->{style};
  return $self->_coerce_parameter_style_object_deep($val, $param) if $param->{style} eq 'deepObject';

  my $schema_type = schema_type $param;
  return $self->_coerce_parameter_style_array($val, $param)  if $schema_type eq 'array';
  return $self->_coerce_parameter_style_object($val, $param) if $schema_type eq 'object';
}

sub _coerce_parameter_style_array {
  my ($self, $val, $param) = @_;
  my $style   = $param->{style};
  my $explode = $param->{explode} // $param->{style} eq 'form' ? true : false;
  my $re;

  if ($style =~ m!^(form|pipeDelimited|spaceDelimited|simple)$!) {
    return $val->{value} = ref $val->{value} eq 'ARRAY' ? $val->{value} : [$val->{value}] if $explode;
    $re = $style eq 'pipeDelimited' ? qr{\|} : $style eq 'spaceDelimited' ? $re = qr{[ ]} : qr{,};
  }
  elsif ($style eq 'label') {
    $re = qr{\.};
    $re = qr{,} if $val->{value} =~ s/^$re// and !$explode;
  }
  elsif ($style eq 'matrix') {
    $re = qr{;\Q$param->{name}\E=};
    $re = qr{,} if $val->{value} =~ s/^$re// and !$explode;
  }

  return $val->{value} = [_split($re, $val->{value})];
}

sub _coerce_parameter_style_object {
  my ($self, $val, $param) = @_;
  my $style   = $param->{style};
  my $explode = $param->{explode} // (grep { $style eq $_ } qw(cookie query)) ? 1 : 0;

  if ($explode) {
    return if $style eq 'form';
    state $style_re = {label => qr{\.}, matrix => qr{;}, simple => qr{,}};
    return unless my $re = $style_re->{$style};
    return if $style eq 'matrix' && $val->{value} !~ s/^;//;
    return if $style eq 'label'  && $val->{value} !~ s/^\.//;
    my $params = Mojo::Parameters->new;
    $params->append(Mojo::Parameters->new($_)) for _split($re, $val->{value});
    return $val->{value} = $params->to_hash;
  }
  else {
    state $style_re = {
      form           => qr{,},
      label          => qr{\.},
      matrix         => qr{,},
      pipeDelimited  => qr{\|},
      simple         => qr{,},
      spaceDelimited => qr{[ ]},
    };
    return unless my $re = $style_re->{$style};
    return if $style eq 'matrix' && $val->{value} !~ s/^;\Q$param->{name}\E=//;
    return if $style eq 'label'  && $val->{value} !~ s/^\.//;
    return $val->{value} = Mojo::Parameters->new->pairs([_split($re, $val->{value})])->to_hash;
  }
}

sub _coerce_parameter_style_object_deep {
  my ($self, $val, $param) = @_;
  my %res;

  for my $k (keys %{$val->{value}}) {
    next unless $k =~ /^\Q$param->{name}\E\[(.*)\]/;

    my @path   = $k =~ m!\[([^]]*)\]!g;
    my $values = ref $val->{value}{$k} eq 'ARRAY' ? $val->{value}{$k} : [$val->{value}{$k}];
    my $node   = \%res;
    while (defined(my $p = shift @path)) {
      if (@path) {
        my $next = $path[0] =~ m!^(|\d+)$! ? [] : {};
        $node = ref $node eq 'ARRAY' ? ($node->[$p] ||= $next) : ($node->{$p} ||= $next);
      }
      elsif ($p eq '') {
        @$node = @$values;
      }
      elsif ($p =~ /^\d+$/) {
        $node->[$p] = $values->[0];
      }
      else {
        $node->{$p} = @$values > 1 ? $values : $values->[0];
      }
    }
  }

  return $val->{value}  = \%res if %res;
  return $val->{exists} = 0;
}

sub _definitions_path_for_ref {
  my ($self, $ref) = @_;
  my $path = Mojo::Path->new($ref->fqn =~ m!^.*#/(components/.+)$!)->to_dir->parts;
  return $path->[0] ? $path : ['definitions'];
}

sub _get_parameter_value {
  my ($self, $param, $get) = @_;
  my $schema_type = schema_type $param;
  my $name        = $param->{name};
  $name = undef if $schema_type eq 'object' && $param->{explode} && ($param->{style} || '') =~ m!^(form|deepObject)$!;

  my $val = $get->{$param->{in}}->($name, $param);
  @$val{qw(in name)} = (@$param{qw(in name)});
  return $val;
}

sub _prefix_error_path { goto &JSON::Validator::Schema::OpenAPIv2::_prefix_error_path }

sub _split {
  my ($re, $val) = @_;
  $val = @$val ? $val->[-1] : '' if ref $val;
  return split /$re/, $val;
}

sub _validate_body {
  my ($self, $direction, $val, $param) = @_;
  $val->{content_type} = $param->{accepts}[0] if !$val->{content_type} and @{$param->{accepts}};

  my $ct = $self->negotiate_content_type($param->{accepts}, $val->{content_type});
  if (@{$param->{accepts}} and !$ct) {
    my $expected = join ', ', @{$param->{accepts}};
    return E "/$param->{name}", [$expected => type => $val->{content_type}];
  }
  if ($param->{required} and !$val->{exists}) {
    return E "/$param->{name}", [qw(object required)];
  }
  if ($val->{exists}) {
    local $self->{"validate_$direction"} = 1;
    my @errors = map { $_->path(_prefix_error_path($param->{name}, $_->path)); $_ }
      $self->validate($val->{value}, $param->{content}{$ct}{schema});
    $val->{valid} = @errors ? 0 : 1;
    return @errors;
  }

  return;
}

1;

=encoding utf8

=head1 NAME

JSON::Validator::Schema::OpenAPIv3 - OpenAPI version 3

=head1 SYNOPSIS

See L<JSON::Validator::Schema::OpenAPIv2/SYNOPSIS>.

=head1 DESCRIPTION

This class represents L<https://spec.openapis.org/oas/3.0/schema/2019-04-02>.

=head1 ATTRIBUTES

=head2 moniker

  $str    = $schema->moniker;
  $schema = $schema->moniker("openapiv2");

Used to get/set the moniker for the given schema. Default value is "openapiv2".

=head2 specification

  my $str    = $schema->specification;
  my $schema = $schema->specification($str);

Defaults to "L<http://swagger.io/v2/schema.json>".

=head1 METHODS

=head2 parameters_for_request

  $parameters = $schema->parameters_for_request([$method, $path]);

Finds all the request parameters defined in the schema, including inherited
parameters. Returns C<undef> if the C<$path> and C<$method> cannot be found.

Example return value:

  [
    {in => "query", name => "q"},
    {in => "body", name => "body", accepts => ["application/json"]},
  ]

The return value MUST not be mutated.

=head2 parameters_for_response

  $array_ref = $schema->parameters_for_response([$method, $path, $status]);

Finds the response parameters defined in the schema. Returns C<undef> if the
C<$path>, C<$method> and C<$status> cannot be found. Will default to the
"default" response definition if C<$status> could not be found and "default"
exists.

Example return value:

  [
    {in => "header", name => "X-Foo"},
    {in => "body", name => "body", accepts => ["application/json"]},
  ]

The return value MUST not be mutated.

=head1 SEE ALSO

L<JSON::Validator::Schema::OpenAPIv2> and L<JSON::Validator>.

=cut
