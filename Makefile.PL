use 5.010001;

use strict;
use warnings;
use utf8;

use ExtUtils::MakeMaker;

my @PREREQ_YAML = !$ENV{JSON_VALIDATOR_PREFER_YAML_PP}
  || eval 'use YAML::XS 0.67;1' ? ('YAML::XS' => '0.67') : ('YAML::PP' => '0.020');

my %WriteMakefileArgs = (
  NAME          => 'JSON::Validator',
  ABSTRACT_FROM => 'lib/JSON/Validator.pm',
  AUTHOR        => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  LICENSE       => 'artistic_2',
  VERSION_FROM  => 'lib/JSON/Validator.pm',
  META_MERGE    => {
    'dynamic_config' => 0,
    'meta-spec'      => {version   => 2},
    'no_index'       => {directory => ['examples', 't']},
    'prereqs'        => {runtime   => {requires => {perl => '5.010001'}}},
    'resources'      => {
      bugtracker => {web => 'https://github.com/mojolicious/json-validator/issues'},
      homepage   => 'https://mojolicious.org',
      license    => ['http://www.opensource.org/licenses/artistic-license-2.0'],
      repository => {
        type => 'git',
        url  => 'https://github.com/mojolicious/json-validator.git',
        web  => 'https://github.com/mojolicious/json-validator',
      },
      x_IRC => 'ircs://irc.libera.chat:6697/#perl-openapi',
    },
  },
  PREREQ_PM     => {'List::Util' => '1.45', 'Mojolicious' => '7.28', 'perl' => 'v5.16.0', @PREREQ_YAML},
  TEST_REQUIRES => {'Test::More' => '1.30', 'Test::Deep'  => '0'},
  test          => {TESTS        => (-e 'META.yml' ? 't/*.t' : 't/*.t xt/*.t')},
);

unless (eval { ExtUtils::MakeMaker->VERSION('6.63_03') }) {
  my $test_requires = delete $WriteMakefileArgs{TEST_REQUIRES};
  @{$WriteMakefileArgs{PREREQ_PM}}{keys %$test_requires} = values %$test_requires;
}

WriteMakefile(%WriteMakefileArgs);
