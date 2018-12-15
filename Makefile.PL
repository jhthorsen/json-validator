use 5.010001;

use strict;
use warnings;
use utf8;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  NAME          => 'JSON::Validator',
  ABSTRACT_FROM => 'lib/JSON/Validator.pm',
  AUTHOR        => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  LICENSE       => 'artistic_2',
  VERSION_FROM  => 'lib/JSON/Validator.pm',
  META_MERGE    => {
    'dynamic_config' => 0,
    'meta-spec'      => {version => 2},
    'no_index'       => {directory => ['examples', 't']},
    'prereqs'        => {runtime => {requires => {perl => '5.010001'}}},
    'resources'      => {
      bugtracker =>
        {web => 'https://github.com/mojolicious/json-validator/issues'},
      homepage   => 'https://mojolicious.org',
      license    => ['http://www.opensource.org/licenses/artistic-license-2.0'],
      repository => {
        type => 'git',
        url  => 'https://github.com/mojolicious/json-validator.git',
        web  => 'https://github.com/mojolicious/json-validator',
      },
      x_IRC => 'irc://irc.freenode.net/#mojo',
    },
  },
  PREREQ_PM     => {'Mojolicious' => '7.28'},
  TEST_REQUIRES => {'Test::More'  => '1.30'},
  test => {TESTS => (-e 'META.yml' ? 't/*.t' : 't/*.t xt/*.t')},
);

unless (eval { ExtUtils::MakeMaker->VERSION('6.63_03') }) {
  my $test_requires = delete $WriteMakefileArgs{TEST_REQUIRES};
  @{$WriteMakefileArgs{PREREQ_PM}}{keys %$test_requires}
    = values %$test_requires;
}

WriteMakefile(%WriteMakefileArgs);
