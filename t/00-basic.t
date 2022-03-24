use strict;
use Test::More;
use File::Find;

plan skip_all => 'AUTHOR_TESTING=1' unless $ENV{AUTHOR_TESTING};

if (($ENV{HARNESS_PERL_SWITCHES} || '') =~ /Devel::Cover/) {
  plan skip_all => 'HARNESS_PERL_SWITCHES =~ /Devel::Cover/';
}
if (!eval 'require Test::Pod; 1') {
  *Test::Pod::pod_file_ok = sub {
  SKIP: { skip "pod_file_ok(@_) (Test::Pod is required)", 1 }
  };
}
if (!eval 'require Test::Pod::Coverage; 1') {
  *Test::Pod::Coverage::pod_coverage_ok = sub {
  SKIP: { skip "pod_coverage_ok(@_) (Test::Pod::Coverage is required)", 1 }
  };
}
if (!eval 'require Test::CPAN::Changes; 1') {
  *Test::CPAN::Changes::changes_file_ok = sub {
  SKIP: { skip "changes_ok(@_) (Test::CPAN::Changes is required)", 4 }
  };
}

my $test_spelling = eval 'require Test::Spelling; Test::Spelling::has_working_spellchecker()';
my $skip_spelling = $test_spelling ? '' : $@ =~ m!(\N+)!s ? $1 : 'No working spellchecker';
Test::Spelling::add_stopwords(<DATA>) if $test_spelling;

my @files;
find({wanted => sub { /\.pm$/ and push @files, $File::Find::name }, no_chdir => 1}, -e 'blib' ? 'blib' : 'lib');

plan tests => @files * 4 + 4;

for my $file (@files) {
  my $module = $file;
  $module =~ s,\.pm$,,;
  $module =~ s,.*/?lib/,,;
  $module =~ s,/,::,g;
  ok eval "use $module; 1", "use $module" or diag $@;
  Test::Pod::pod_file_ok($file);
  Test::Pod::Coverage::pod_coverage_ok($module, {also_private => [qr/^[A-Z_]+$/]});
  pod_file_spelling_ok($file);
}

Test::CPAN::Changes::changes_file_ok();

sub pod_file_spelling_ok {
SKIP: {
    skip "pod_file_spelling_ok(@_) ($skip_spelling)", 1 if $skip_spelling;
    Test::Spelling::pod_file_spelling_ok($_[0]);
  }
}

__DATA__
additionalItems
additionalProperties
allOf
alphanum
anyOf
basePath
bc
Böhmer
const
DefaultResponse
DT
Etheridge
fff
formData
Goess
Henning
iban
ipv
IRI
Joi
joi
JSONPatch
maxItems
maxLength
maxProperties
minItems
minLength
minProperties
multipleOf
NID
nid
NSS
nss
oneOf
OpenAPI
openapiv
Petstore
Renvoize
Schemas
schemas
str
Thorsen
ua
unevaluatedItems
unevaluatedProperties
uniqueItems
UUIDv
validator
validators
