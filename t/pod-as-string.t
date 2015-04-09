use Mojo::Base -strict;
use Mojo::Util 'slurp';
use Test::More;
use Swagger2;
use File::Spec::Functions 'catfile';

my $pod_file = catfile qw( t data pod-as-string.pod );
plan skip_all => "Cannot read $pod_file" unless -r $pod_file;

my @expected = split /\n/, slurp $pod_file;
my $swagger  = Swagger2->new->load('t/data/pod-as-string.json');
my $pod      = $swagger->pod;
my $fail     = 0;

isa_ok($pod, 'Swagger2::POD');

my $i = 0;
for my $line (split /\n/, $pod->to_string) {
  my $expected = shift @expected;
  my $desc     = $line;
  $desc =~ s/[^\w\s]//g;
  $i++;
  next unless $desc =~ /\w/;
  is $line, $expected, "$i: $desc" or $fail = 1;
}

if ($fail and $ENV{PRINT_DOC}) {
  print $pod->to_string;
}

my $identifier = $swagger->tree->data->{paths}{'/any-of'}{get}{responses}{200}{schema}{properties}{identifier};
$identifier->{allOf} = delete $identifier->{anyOf};
like $swagger->pod->to_string, qr{// All of the below:}, 'allOf';

$identifier->{oneOf} = delete $identifier->{allOf};
like $swagger->pod->to_string, qr{// One of the below:}, 'oneOf';

done_testing;
