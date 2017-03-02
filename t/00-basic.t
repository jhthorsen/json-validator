use Test::More;
use File::Find;

if (!eval 'use Test::Pod; 1') {
  *Test::Pod::pod_file_ok = sub {
  SKIP: { skip "pod_file_ok(@_) (Test::Pod is required)", 1 }
  };
}
if (!eval 'use Test::CPAN::Changes; 1') {
  *Test::CPAN::Changes::changes_file_ok = sub {
  SKIP: { skip "changes_ok(@_) (Test::CPAN::Changes is required)", 4 }
  };
}

find(
  {wanted => sub { /\.pm$/ and push @files, $File::Find::name }, no_chdir => 1},
  -e 'blib' ? 'blib' : 'lib',
);

plan tests => @files * 2 + 4;

for my $file (@files) {
  my $module = $file;
  $module =~ s,\.pm$,,;
  $module =~ s,.*/?lib/,,;
  $module =~ s,/,::,g;
  ok eval "use $module; 1", "use $module" or diag $@;
  Test::Pod::pod_file_ok($file);
}

Test::CPAN::Changes::changes_file_ok();
