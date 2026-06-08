use Mojo::Base -strict;
use JSON::Validator::Schema::OpenAPIv3;
use Mojo::JSON qw(true);
use Test::More;

# Regression test for GH #272 ("heisenbug with openapi 3.1.* schema").
#
# Validating an OpenAPI 3.1 document whose parameter uses a $ref schema
# intermittently produced a false "/components/parameters/Id/$ref: Missing
# property." error. Root cause: recursive_data_protection's "seen" cache keyed on
# stringified memory addresses ("$schema:$data"); transient merged-schema hashrefs
# (built while following the meta-schema's $refs) were freed mid-validation and
# their addresses reused, colliding with stale cached error lists.
#
# It is a heisenbug (address reuse, independent of the hash seed), so we validate
# many times and assert the document is *always* valid.

sub spec {
  return {
    openapi    => '3.1.0',
    info       => {version => '1.0', title => 'whatever'},
    components => {
      parameters => {
        Id => {in => 'path', name => 'id', required => true, schema => {'$ref' => '#/components/schemas/IdType'}},
      },
      schemas => {IdType => {type => 'integer'}},
    },
  };
}

my $spec_url   = 'https://spec.openapis.org/oas/3.1/schema/2021-05-20';
my $iterations = 500;

my (%errors, $failures);
for (1 .. $iterations) {
  my $schema = JSON::Validator::Schema::OpenAPIv3->new(spec(), specification => $spec_url);
  next unless my @e = @{$schema->errors};
  $failures++;
  $errors{"$_"}++ for @e;
}

is $failures, undef, "valid 3.1 \$ref parameter stays valid across $iterations validations (#272)"
  or diag "spurious errors: " . join(', ', map {"$_ x$errors{$_}"} sort keys %errors);

done_testing;
