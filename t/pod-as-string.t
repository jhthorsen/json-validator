use Mojo::Base -strict;
use Mojo::Util 'slurp';
use Test::More;
use Swagger2;
use File::Spec::Functions 'catfile';

my $pod_file = catfile qw( t data petstore.pod );
plan skip_all => "Cannot read $pod_file" unless -r $pod_file;

my @expected = split /\n/, slurp $pod_file;
my $swagger  = Swagger2->new->load('t/data/petstore.json');
my $pod      = $swagger->pod;

isa_ok($pod, 'Swagger2::POD');

my $i = 0;
for my $line (split /\n/, $pod->to_string) {
  my $expected = shift @expected;
  my $desc     = $line;
  $desc =~ s/[^\w\s]//g;
  $i++;
  next unless $desc =~ /\w/;
  is $line, $expected, "$i: $desc";
}

done_testing;
