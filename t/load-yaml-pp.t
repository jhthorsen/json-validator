BEGIN {
  unshift @INC, sub {
    my $file = $_[1];
    die "Skipping $file in this test" if $file =~ m!YAML\W+XS\.pm$!;
  };
}

use Test::More;

plan skip_all => 'YAML::PP not available'
  unless eval 'require JSON::Validator;1';
ok $INC{'YAML/PP.pm'}, 'YAML::PP was loaded';
ok !$INC{'YAML/XS.pm'}, 'YAML::XS was not loaded';

done_testing;

