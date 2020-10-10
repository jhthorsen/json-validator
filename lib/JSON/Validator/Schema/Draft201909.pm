package JSON::Validator::Schema::Draft201909;
use Mojo::Base 'JSON::Validator::Schema::Draft7';

use JSON::Validator::Util qw(E is_type);
use Scalar::Util qw(refaddr);

has anchors       => sub { +{} };
has specification => 'https://json-schema.org/draft/2019-09/schema';

sub _build_formats {
  my $formats = shift->SUPER::_build_formats;
  $formats->{duration} = JSON::Validator::Formats->can('check_duration');
  $formats->{uuid}     = JSON::Validator::Formats->can('check_uuid');
  return $formats;
}

sub _definitions_path_for_ref { ['$defs'] }

sub _find_and_resolve_refs {
  my ($self, $base_url, $schema) = @_;
  my %root = is_type($schema, 'HASH') ? %$schema : ();

  my (@topics, @rrefs, @refs, %seen) = ($schema);
  while (@topics) {
    my $topic = shift @topics;

    if (is_type $topic, 'ARRAY') {
      push @topics, @$topic;
    }
    elsif (is_type $topic, 'HASH') {
      next if $seen{refaddr($topic)}++;

      unless (tied %$topic) {
        push @refs,  [$topic, $base_url] if $topic->{'$ref'}          and !ref $topic->{'$ref'};
        push @rrefs, [$topic, $base_url] if $topic->{'$recursiveRef'} and !ref $topic->{'$recursiveRef'};
      }

      if ($topic->{'$anchor'} && !ref $topic->{'$anchor'}) {
        $self->anchors->{$topic->{'$anchor'}} = $topic;
      }

      push @topics, map { $topic->{$_} } grep { ref $topic->{$_} and !m!^\$(ref|recursiveRef)$! } keys %$topic;
    }
  }

  my $N = 0;
  while (@refs) {
    my ($topic, $id) = @{shift @refs};
    next if is_type $topic, 'BOOL';
    next if !$topic->{'$ref'} or ref $topic->{'$ref'};
    my $base = Mojo::URL->new($id || $base_url)->fragment(undef);
    my ($other, $ref_url, $fqn) = $self->_resolve_ref($topic->{'$ref'}, $base, \%root);
    tie %$topic, 'JSON::Validator::Ref', $other, "$ref_url", "$fqn";
    push @refs, [$other, $fqn];
    die if $N++ > 50;
  }
}

sub _resolve_ref {
  my ($self, $ref_url, $base_url, $root) = @_;
  return $self->anchors->{$1}, $ref_url, $ref_url if $ref_url =~ m!^#([A-Za-z].*)$!;
  return $self->SUPER::_resolve_ref($ref_url, $base_url, $root);
}

sub _validate_type_array_contains {
  my ($self, $data, $path, $schema) = @_;
  return unless exists $schema->{contains};
  return if defined $schema->{minContains} and $schema->{minContains} == 0;

  my ($n_valid, @e, @errors) = (0);
  for my $i (0 .. @$data - 1) {
    my @tmp = $self->_validate($data->[$i], "$path/$i", $schema->{contains});
    @tmp ? push @e, \@tmp : $n_valid++;
  }

  push @errors, map {@$_} @e if @e >= @$data;
  push @errors, E $path, [array => 'maxContains']
    if exists $schema->{maxContains} and $n_valid > $schema->{maxContains};
  push @errors, E $path, [array => 'minContains'] if $schema->{minContains} and $n_valid < $schema->{minContains};
  push @errors, E $path, [array => 'contains']    if not @$data;
  return @errors;
}

sub _validate_type_array_items {
  my ($self, $data, $path, $schema) = @_;
  my (@errors, @unevaluated);

  if (ref $schema->{items} eq 'ARRAY') {
    my $additional_items = $schema->{additionalItems} // {};
    my @rules            = @{$schema->{items}};

    if ($additional_items) {
      push @rules, $additional_items while @rules < @$data;
    }

    if (@rules >= @$data) {
      for my $i (0 .. @$data - 1) {
        my @e = $self->_validate($data->[$i], "$path/$i", $rules[$i]);
        push @errors,      @e;
        push @unevaluated, $i if @e;
      }
    }
    elsif (!$additional_items) {
      push @unevaluated, 0 .. @$data - 1;
      push @errors, E $path, [array => additionalItems => int(@$data), int(@rules)];
    }
  }
  elsif (exists $schema->{items}) {
    for my $i (0 .. @$data - 1) {
      my @e = $self->_validate($data->[$i], "$path/$i", $schema->{items});
      push @errors,      @e;
      push @unevaluated, $i if @e;
    }
  }
  else {
    push @unevaluated, 0 .. @$data - 1;
  }

  if (is_type $schema->{unevaluatedItems}, 'BOOL') {
    warn Mojo::Util::dumper(\@unevaluated, $data, $schema);
  }

  return @errors;
}

1;

=encoding utf8

=head1 NAME

JSON::Validator::Schema::Draft201909 - JSON-Schema Draft 2019-09

=head1 SYNOPSIS

See L<JSON::Validator::Schema/SYNOPSIS>.

=head1 DESCRIPTION

This class represents
L<https://json-schema.org/specification-links.html#2019-09-formerly-known-as-draft-8>.

=head1 ATTRIBUTES

=head2 specification

  my $str = $schema->specification;

Defaults to "L<https://json-schema.org/draft/2019-09/schema>".

=head1 SEE ALSO

L<JSON::Validator::Schema>.

=cut
