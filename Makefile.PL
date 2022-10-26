use 5.016;
use strict;
use warnings;
use utf8;
use ExtUtils::MakeMaker;

my $GITHUB_URL  = 'https://github.com/jhthorsen/json-validator';
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
    'no_index'       => {directory => [qw(examples t)]},
    'prereqs'        => {runtime   => {requires => {perl => '5.016'}}},
    'resources'      => {
      bugtracker => {web => "$GITHUB_URL/issues"},
      homepage   => $GITHUB_URL,
      license    => ['http://www.opensource.org/licenses/artistic-license-2.0'],
      repository => {type => 'git', url => "$GITHUB_URL.git", web => $GITHUB_URL},
      x_IRC      => {url  => 'irc://irc.libera.chat/#perl-openapi', web => 'https://web.libera.chat/#perl-openapi'},
    },
    'x_contributors' => [
      'Aleksandr Orlenko <zxteam@gmail.com>',
      'Alexander Hartmaier <alexander.hartmaier@t-systems.at>',
      'Alexander Karelas <karjala@cpan.org>',
      'Bernhard Graf <augensalat@gmail.com>',
      'Brad Barden <brad+github@13os.net>',
      'Dagfinn Ilmari Mannsåker <ilmari@ilmari.org>',
      'Daniel Böhmer <boehmer@strato.de>',
      'David Cantrell <david@cantrell.org.uk>',
      'Ed J <mohawk2@users.noreply.github.com>',
      'Ere Maijala <ere.maijala@helsinki.fi>',
      'Fabrizio Gennari <fabrizio.ge@tiscali.it>',
      'Ilya Rassadin <elcamlost@gmail.com>',
      'Jan Henning Thorsen <jhthorsen@cpan.org>',
      'Jason Cooper <J.L.Cooper@lboro.ac.uk>',
      'Karen Etheridge <ether@cpan.org>',
      'Kenichi Ishigaki <ishigaki@cpan.org>',
      'Kevin M. Goess <kgoess@craigslist.org>',
      'Kirill Matusov <freetransform@gmail.com>',
      'Krasimir Berov <k.berov@gmail.com>',
      'Lari Taskula <lari.taskula@jns.fi>',
      'Lee Johnson <lee@givengain.ch>',
      'Martin Renvoize <martin.renvoize@gmail.com>',
      'Mattias Päivärinta <mattias.paivarinta@iis.se>',
      'Michael Jemmeson <mjemmeson@cpan.org>',
      'Michael Schout <mschout@gkg.net>',
      'Mohammad S Anwar <mohammad.anwar@yahoo.com>',
      'Nick Morrott <knowledgejunkie@gmail.com>',
      'Pierre-Aymeric Masse <pamasse@afnic.fr>',
      'Roy Storey <kiwiroy@users.noreply.github.com>',
      'Russell Jenkins <russell.jenkins@strategicdata.com.au>',
      'Sebastian Riedel <sri@cpan.org>',
      'Stephan Hradek <github@hradek.net>',
      'Tim Stallard <tim@mythic-beasts.com>',
      'Zoffix Znet <cpan@zoffix.com>',
    ],
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
