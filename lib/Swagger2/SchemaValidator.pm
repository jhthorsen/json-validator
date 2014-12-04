package Swagger2::SchemaValidator;

###
# JSONSchema Validator - Validates JavaScript objects using JSON Schemas
#	(http://www.json.com/json-schema-proposal/)
#
# Copyright (c) 2007 Kris Zyp SitePen (www.sitepen.com)
# Licensed under the MIT (MIT-LICENSE.txt) license.
#To use the validator call JSONSchema.validate with an instance object and an optional schema object.
#If a schema is provided, it will be used to validate. If the instance object refers to a schema (self-validating),
#that schema will be used to validate and the schema parameter is not necessary (if both exist,
#both validations will occur).
#The validate method will return an array of validation errors. If there are no errors, then an
#empty list will be returned. A validation error will have two properties:
#"property" which indicates which property had the error
#"message" which indicates what the error was
##

# TODO: {id}, {dependencies}

use Mojo::Base -strict;
use Mojo::JSON;
use constant FALSE => Mojo::JSON->false;
use constant TRUE  => Mojo::JSON->true;
no autovivification;
use POSIX qw[modf];
use Scalar::Util qw[blessed];

sub new {
  my ($class, %args) = @_;
  $args{hyper}  //= undef;    # TODO
  $args{errors} //= [];
  $args{format} //= {};
  return bless \%args, $class;
}

sub validate {
  my ($self, $instance, $schema) = @_;
  ## Summary:
  ##  	To use the validator call JSONSchema.validate with an instance object and an optional schema object.
  ## 		If a schema is provided, it will be used to validate. If the instance object refers to a schema (self-validating),
  ## 		that schema will be used to validate and the schema parameter is not necessary (if both exist,
  ## 		both validations will occur).
  ## 		The validate method will return an object with two properties:
  ## 			valid: A boolean indicating if the instance is valid by the schema
  ## 			errors: An array of validation errors. If there are no errors, then an
  ## 					empty list will be returned. A validation error will have two properties:
  ## 						property: which indicates which property had the error
  ## 						message: which indicates what the error was
  ##
  return $self->_validate($instance, $schema, FALSE);
}

sub checkPropertyChange {
  my ($self, $value, $schema, $property) = @_;
  $property //= 'property';
  ## Summary:
  ## 		The checkPropertyChange method will check to see if an value can legally be in property with the given schema
  ## 		This is slightly different than the validate method in that it will fail if the schema is readonly and it will
  ## 		not check for self-validation, it is assumed that the passed in value is already internally valid.
  ## 		The checkPropertyChange method will return the same object type as validate, see JSONSchema.validate for
  ## 		information.
  ##
  return $self->_validate($value, $schema, $property);
}

sub _validate {
  my ($self, $instance, $schema, $_changing) = @_;

  $self->{errors} = [];

  if ($schema) {
    $self->checkProp($instance, $schema, '', ($_changing // ''), $_changing);
  }
  if (!$_changing and defined $instance and ref $instance eq 'HASH' and defined $instance->{'$schema'}) {
    $self->checkProp($instance, $instance->{'$schema'}, '', '', $_changing);
  }

  return {valid => (@{$self->{errors}} ? FALSE : TRUE), errors => $self->{errors},};
}

sub checkType {
  my ($self, $type, $value, $path, $_changing, $schema) = @_;

  my @E;
  my $addError = sub {
    my ($message) = @_;
    my $e = {property => $path, message => $message};
    foreach (qw(title description)) {
      $e->{$_} = $schema->{$_} if defined $schema->{$_};
    }
    push @E, $e;
  };

  if ($type) {
    if (ref $type eq 'ARRAY') {
      my @unionErrors;
    TYPE: foreach my $t (@$type) {
        @unionErrors = $self->checkType($t, $value, $path, $_changing, $schema);
        last unless @unionErrors;
      }
      return @unionErrors if @unionErrors;
    }
    elsif (ref $type eq 'HASH') {
      local $self->{errors} = [];
      $self->checkProp($value, $type, $path, undef, $_changing);
      return @{$self->{errors}};
    }
    elsif (!$self->jsMatchType($type, $value)) {
      $addError->($self->jsGuessType($value) . " value found, but a $type is required");
      return @E;
    }
  }
  return;
}

# validate a value against a property definition
sub checkProp {
  my ($self, $value, $schema, $path, $i, $_changing) = @_;
  my $l;
  $path .= $path ? ".${i}" : "\$${i}";

  my $addError = sub {
    my ($message) = @_;
    my $e = {property => $path, message => $message};
    foreach (qw(title description)) {
      $e->{$_} = $schema->{$_} if defined $schema->{$_};
    }
    push @{$self->{errors}}, $e;
  };

  if (ref $schema ne 'HASH' and ($path or ref $schema ne 'CODE')) {
    if (ref $schema eq 'CODE') {

      # ~TOBYINK: I don't think this makes any sense in Perl
      $addError->("is not an instance of the class/constructor " . $schema);
    }
    elsif ($schema) {
      $addError->("Invalid schema/property definition " . $schema);
    }
    return undef;
  }

  eval { $self->{'hyper'}->process_includes($schema, $self->{'base'}) };

  if ($_changing and $schema->{'readonly'}) {
    $addError->("is a readonly field, it can not be changed");
  }
  if ($schema->{'extends'}) {
    $self->checkProp($value, $schema->{'extends'}, $path, $i, $_changing);
  }

  # validate a value against a type definition
  if (!defined $value) {
    my $required;
    $required = !$schema->{'optional'} if exists $schema->{'optional'};
    $required = $schema->{'required'}  if $schema->{'required'};

    $addError->("is missing and it is required") if $required;
  }
  else {
    push @{$self->{errors}}, $self->checkType($schema->{'type'}, $value, $path, $_changing, $schema);

    if (defined $schema->{'disallow'} and !$self->checkType($schema->{'disallow'}, $value, $path, $_changing)) {
      $addError->(" disallowed value was matched");
    }
    else {
      if (ref $value eq 'ARRAY') {
        my $items = $schema->{items};

        if (ref $items eq 'ARRAY') {    # check each item in $schema->{items} vs corresponding array value
          my $i = 0;
          while ($i < @$items) {
            my $x = defined $value->[$i] ? $value->[$i] : undef;
            push @{$self->{errors}}, $self->checkProp($x, $items->[$i], $path, $i, $_changing);
            $i++;
          }
          if (exists $schema->{additionalItems}) {
            my $additional_items = $schema->{additionalItems};
            if (!$additional_items) {
              if (defined $value->[$i]) {
                $addError->("has too many items");
              }
            }
            else {
              while ($i < @$value) {
                my $x = defined $value->[$i] ? $value->[$i] : undef;
                push @{$self->{errors}}, $self->checkProp($x, $additional_items, $path, $i, $_changing);
                $i++;
              }
            }
          }
        }
        elsif (ref $items eq 'HASH') {    # check single $schema->{items} hash vs all values in array
          for (my $i = 0; $i < @$value; $i++) {
            my $x = defined $value->[$i] ? $value->[$i] : undef;
            push @{$self->{errors}}, $self->checkProp($x, $items, $path, $i, $_changing);
          }
        }
        if ($schema->{'minItems'} and scalar @$value < $schema->{'minItems'}) {
          $addError->("There must be a minimum of " . $schema->{'minItems'} . " in the array");
        }
        if ($schema->{'maxItems'} and scalar @$value > $schema->{'maxItems'}) {
          $addError->("There must be a maximum of " . $schema->{'maxItems'} . " in the array");
        }
        if ($schema->{'uniqueItems'}) {
          my %hash;
          $hash{to_json([$_], {canonical => 1, convert_blessed => 1})}++ for @$value;
          $addError->("Array must not contain duplicates.") unless scalar(keys %hash) == scalar(@$value);
        }
      }
      elsif (defined $schema->{'properties'}
        or defined $schema->{'additionalProperties'}
        or defined $schema->{'patternProperties'}
        or $schema->{'type'} eq 'object')
      {
        push @{$self->{errors}},
          $self->checkObj(
          $value, $path,
          $schema->{'properties'},
          $schema->{'additionalProperties'},
          $schema->{'patternProperties'}, $_changing
          );
      }

      if ($schema->{'pattern'} and $self->jsMatchType('string', $value)) {
        my $x = $schema->{'pattern'};
        $addError->("does not match the regex pattern $x") unless $value =~ /$x/;
      }
      if ($schema->{'format'} and ($self->jsMatchType('string', $value) or $self->jsMatchType('number', $value))) {
        my $format_checker = exists $self->{format}{$schema->{format}} ? $self->{format}{$schema->{format}} : qr//;

        no if $] >= 5.017011, warnings => 'experimental::smartmatch';
        $addError->("does not match format " . $schema->{format}) unless $value ~~ $format_checker;
      }
      if ($schema->{'maxLength'} and $self->jsMatchType('string', $value) and length($value) > $schema->{'maxLength'}) {
        $addError->("may only be " . $schema->{'maxLength'} . " characters long");
      }
      if ($schema->{'minLength'} and $self->jsMatchType('string', $value) and length($value) < $schema->{'minLength'}) {
        $addError->("must be at least " . $schema->{'minLength'} . " characters long");
      }
      if (defined $schema->{'minimum'} and not $self->jsMatchType('number', $value)) {
        if ((defined $schema->{'minimumCanEqual'} and not $schema->{'minimumCanEqual'})
          or $schema->{'exclusiveMinimum'})
        {
          $addError->("must be greater than minimum value '" . $schema->{'minimum'} . "'")
            if $value lt $schema->{'minimum'};
        }
        else {
          $addError->("must be greater than or equal to minimum value '" . $schema->{'minimum'} . "'")
            if $value le $schema->{'minimum'};
        }
      }
      elsif (defined $schema->{'minimum'}) {
        if ((defined $schema->{'minimumCanEqual'} and not $schema->{'minimumCanEqual'})
          or $schema->{'exclusiveMinimum'})
        {
          $addError->("must be greater than minimum value " . $schema->{'minimum'})
            unless $value > $schema->{'minimum'};
        }
        else {
          $addError->("must be greater than or equal to minimum value " . $schema->{'minimum'})
            unless $value >= $schema->{'minimum'};
        }
      }
      if (defined $schema->{'maximum'} and not $self->jsMatchType('number', $value)) {
        if ((defined $schema->{'maximumCanEqual'} and not $schema->{'maximumCanEqual'})
          or $schema->{'exclusiveMaximum'})
        {
          $addError->("must be less than or equal to maximum value '" . $schema->{'maximum'} . "'")
            if $value gt $schema->{'maximum'};
        }
        else {
          $addError->("must be less than or equal to maximum value '" . $schema->{'maximum'} . "'")
            if $value ge $schema->{'maximum'};
        }
      }
      elsif (defined $schema->{'maximum'}) {
        if ((defined $schema->{'maximumCanEqual'} and not $schema->{'maximumCanEqual'})
          or $schema->{'exclusiveMaximum'})
        {
          $addError->("must be less than maximum value " . $schema->{'maximum'}) unless $value < $schema->{'maximum'};
        }
        else {
          $addError->("must be less than or equal to maximum value " . $schema->{'maximum'})
            unless $value <= $schema->{'maximum'};
        }
      }
      if ($schema->{'enum'}) {
        my %enum;
        $enum{to_json([$_], {canonical => 1, convert_blessed => 1})}++ for @{$schema->{'enum'}};
        my $this_value = to_json([$value], {canonical => 1, convert_blessed => 1});
        $addError->("does not have a value in the enumeration {" . (join ",", @{$schema->{'enum'}}) . '}')
          unless exists $enum{$this_value};
      }
      if ($schema->{'divisibleBy'} and $self->jsMatchType('number', $value)) {
        my ($frac, $int) = modf($value / $schema->{'divisibleBy'});
        $addError->("must be divisible by " . $schema->{'divisibleBy'}) if $frac;
      }
      elsif ($schema->{'maxDecimal'} and $self->jsMatchType('number', $value))    # ~TOBYINK: back-compat
      {
        my $regexp = "\\.[0-9]{" . ($schema->{'maxDecimal'} + 1) . ",}";
        $addError->("may only have " . $schema->{'maxDecimal'} . " digits of decimal places") if $value =~ /$regexp/;
      }
    }
  }
  return;
};    # END: sub checkProp


sub checkObj {
  my ($self, $instance, $path, $objTypeDef, $additionalProp, $patternProp, $_changing) = @_;
  my @errors;

  my $addError = sub {
    my ($message) = @_;
    my $e = {property => $path, message => $message};
    push @{$self->{errors}}, $e;
  };

  eval { $self->{'hyper'}->process_includes($objTypeDef, $self->{'base'}) };

  if (ref $objTypeDef eq 'HASH') {
    if (ref $instance ne 'HASH') {
      $addError->("an object is required");
    }

    foreach my $i (keys %$objTypeDef) {
      unless ($i =~ /^__/) {
        my $value = defined $instance->{$i} ? $instance->{$i} : undef;
        my $propDef = $objTypeDef->{$i};
        $self->checkProp($value, $propDef, $path, $i, $_changing);
      }
    }
  }    # END: if (ref $objTypeDef eq 'HASH')

  foreach my $i (keys %$instance) {
    my $prop_is_hidden             = ($i =~ /^__/);
    my $prop_is_explicitly_allowed = (defined $objTypeDef and defined $objTypeDef->{$i});
    my $prop_is_implicitly_allowed = (!!$additionalProp or !!$patternProp or not defined $additionalProp);

    unless ($prop_is_hidden or $prop_is_explicitly_allowed or $prop_is_implicitly_allowed) {
      $addError->("The property $i is not defined in the schema and the schema does not allow additional properties");
    }

    # TOBY: back-compat
    my $requires = $objTypeDef && $objTypeDef->{$i} && $objTypeDef->{$i}->{'requires'};
    if (defined $requires and not defined $instance->{$requires}) {
      $addError->("the presence of the property $i requires that $requires also be present");
    }

    my $deps = $objTypeDef && $objTypeDef->{$i} && $objTypeDef->{$i}->{'dependencies'};
    if (defined $deps) {

      # TODO
    }

    my $value = defined $instance->{$i} ? $instance->{$i} : undef;
    if (defined $objTypeDef and ref $objTypeDef eq 'HASH' and !defined $objTypeDef->{$i}) {
      $self->checkProp($value, $additionalProp, $path, $i, $_changing);
    }

    if (defined $patternProp) {
      while (my ($pattern, $scm) = each %$patternProp) {
        $self->checkProp($value, $scm, $path, $i, $_changing) if $i =~ /$pattern/;
      }
    }

    if (!$_changing and defined $value and ref $value eq 'HASH' and defined $value->{'$schema'}) {
      push @errors, $self->checkProp($value, $value->{'$schema'}, $path, $i, $_changing);
    }
  }
  return @errors;
}

sub jsMatchType {
  my ($self, $type, $value) = @_;

  if (lc $type eq 'string') {
    return (ref $value) ? FALSE : TRUE;
  }

  if (lc $type eq 'number') {
    return ($value =~ /^\-?[0-9]*(\.[0-9]*)?$/ and length $value) ? TRUE : FALSE;
  }

  if (lc $type eq 'integer') {
    return ($value =~ /^\-?[0-9]+$/) ? TRUE : FALSE;
  }

  if (lc $type eq 'boolean') {
    return FALSE if (!defined $value);
    return TRUE  if (ref $value eq 'SCALAR' and $$value == 0 || $$value == 1);
    return TRUE  if ($value eq TRUE);
    return TRUE  if ($value eq FALSE);
    return TRUE  if (ref $value eq 'JSON::PP::Boolean');
    return TRUE  if (ref $value eq 'JSON::XS::Boolean');
    return FALSE;
  }

  if (lc $type eq 'object') {
    return (ref $value eq 'HASH') ? TRUE : FALSE;
  }

  if (lc $type eq 'array') {
    return (ref $value eq 'ARRAY') ? TRUE : FALSE;
  }

  if (lc $type eq 'null') {
    return undef;
  }

  if (lc $type eq 'any') {
    return TRUE;
  }

  if (lc $type eq 'none') {
    return FALSE;
  }

  if (blessed($value) and $value->isa($type)) {
    return TRUE;
  }
  elsif (ref($value) and ref($value) eq $type) {
    return TRUE;
  }

  return FALSE;
}

sub jsGuessType {
  my ($self, $value) = @_;

  return 'null' unless defined $value;

  return 'object' if ref $value eq 'HASH';

  return 'array' if ref $value eq 'ARRAY';

  return 'boolean' if (ref $value eq 'SCALAR' and $$value == 0 and $$value == 1);

  return 'boolean' if ref $value =~ /^JSON::(.*)::Boolean$/;

  return ref $value if ref $value;

  return 'integer' if $value =~ /^\-?[0-9]+$/;

  return 'number' if $value =~ /^\-?[0-9]*(\.[0-9]*)?$/;

  return 'string';
}

1;

__END__

=head1 NAME

Swagger2::SchemaValidator - JSON schema validator

=head1 DESCRIPTION

This module is mostly copy/paste from L<JSON::Schema::Helper>.

=head1 METHODS

=head2 checkObj

=head2 checkProp

=head2 checkPropertyChange

=head2 checkType

=head2 jsGuessType

=head2 jsMatchType

=head2 new

=head2 validate

=head1 SEE ALSO

L<JSON::Schema>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

Copyright 2007-2009 Kris Zyp.

Copyright 2010-2012 Toby Inkster.

This module is tri-licensed. It is available under the X11 (a.k.a. MIT)
licence; you can also redistribute it and/or modify it under the same
terms as Perl itself.

=head2 a.k.a. "The MIT Licence"

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

=cut
