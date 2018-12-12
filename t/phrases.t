use Mojo::Base -strict;
use JSON::Validator::Error;
use JSON::Validator;
use Test::More;

my %phrases;
my $fh = Mojo::File->new($INC{'JSON/Validator.pm'})->open('<');
while (<$fh>) {
  next unless /E\s+[^,]+,\s*(.*)/;
  my $phrase = $1;
  next unless $phrase =~ s!.*?["']([^']+)['"].*!$1!;
  next if $phrase eq '%1 %2';
  note "found $phrase";
  $phrases{$phrase} = ['validator'];
}

$fh = Mojo::File->new($INC{'JSON/Validator/Error.pm'})->open('<');
my $record;
while (<$fh>) {
  last if /^=head1 ATTRIBUTES/;
  next unless $record ||= /^=head1 PHRASES/;
  next unless /^  ([^#].+)/;
  note "documented $1";
  push @{$phrases{$1}}, 'error';
}

for my $phrase (sort keys %phrases) {
  if ($phrases{$phrase}[0] eq 'error') {
    $fh = Mojo::File->new($INC{'JSON/Validator.pm'})->open('<');
    while (<$fh>) {
      next unless /'$phrase'/;
      unshift @{$phrases{$phrase}}, 'validator';
      last;
    }
  }

  is_deeply $phrases{$phrase}, ['validator', 'error'], "documented $phrase";
}

done_testing;
