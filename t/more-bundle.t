use Mojo::Base -strict;
use JSON::Validator;
use Test::Deep;
use Test::More;

plan skip_all => 'YAML::XS is not installed'
  unless JSON::Validator->YAML_SUPPORT;

# these are triples:
# - schema name to extract from schema file(s) with bundle()
# - expected result
# - test name.
my @tests = (
  [
    'i_have_nested_refs',
    {
      definitions => {
        ref1 => {type => 'array', items => {'$ref' => '#/definitions/ref2'}},
        ref2 => {type => 'string', minLength => 1},
      },

      # begin i_have_nested_refs definition
      type       => 'object',
      properties => {
        my_key1 => {'$ref' => '#/definitions/ref1'},
        my_key2 => {'$ref' => '#/definitions/ref1'},
      },
    },
    'find and resolve nested $refs; main schema is at the top level',
  ],

  [
    'i_have_a_recursive_ref',
    {
      definitions => {
        i_have_a_recursive_ref => {
          type       => 'object',
          properties => {
            name     => {type => 'string'},
            children => {
              type    => 'array',
              items   => {'$ref' => '#/definitions/i_have_a_recursive_ref'},
              default => [],
            },
          },
        },
      },

      # begin i_have_a_recursive_ref definition
      # it is duplicated with the above, but there is no other way,
      # because $ref cannot be combined with other sibling keys
      type       => 'object',
      properties => {
        name     => {type => 'string'},
        children => {
          type    => 'array',
          items   => {'$ref' => '#/definitions/i_have_a_recursive_ref'},
          default => [],
        },
      },
    },
    'find and resolve recursive $refs',
  ],

  [
    'i_have_a_ref_to_another_file',
    {
      definitions => {
        my_name    => {type => 'string', minLength => 2},
        my_address => {
          type       => 'object',
          properties => {
            street => {type   => 'string'},
            city   => {'$ref' => '#/definitions/my_name'},
          },
        },
        ref1 => {type => 'array', items => {'$ref' => '#/definitions/ref2'}},
        ref2 => {type => 'string', minLength => 1},
      },

      # begin i_have_a_ref_to_another_file definition
      type       => 'object',
      properties => {

        # these ref targets are rewritten
        name    => {'$ref' => '#/definitions/my_name'},
        address => {'$ref' => '#/definitions/my_address'},
        secrets => {'$ref' => '#/definitions/ref1'},
      },
    },
    'find and resolve references to other local files',
  ],

  [
    'i_am_a_ref',
    {
      definitions => {ref2 => {type => 'string', minLength => 1}},

      # begin i_am_a_ref definition - which is actually ref1
      type  => 'array',
      items => {'$ref' => '#/definitions/ref2'},
    },
    'find and resolve references where the definition itself is a ref',
  ],

  [
    'i_am_a_ref_level_1',
    {
      # begin i_am_a_ref definition - which is actually (eventually) ref3
      type => 'integer',
    },
    'find and resolve references where the definition itself is a ref, multiple times over',
  ],

  [
    'i_have_refs_with_the_same_name',
    {
      definitions => {i_am_a_ref_with_the_same_name => {type => 'string'}},

      # begin i_have_a_ref_with_the_same_name definition
      type => 'object',
      properties =>
        {me => {'$ref' => '#/definitions/i_am_a_ref_with_the_same_name'}},
    },
    '$refs which are simply $refs themselves are traversed automatically during resolution',
  ],

  [
    'i_am_a_ref_with_the_same_name',
    {
      # begin i_am_a_ref_with_the_same_name definition
      # - pulled from secondary file
      type => 'string',
    },
    '$refs which are simply $refs themselves are traversed automatically during resolution, at the top level too',
  ],

  [
    'i_contain_refs_to_same_named_definitions',
    {
      definitions => code(sub {
        my $got = shift;
        return (0, 'expected hash with 2 keys')
          unless ref($got) eq 'HASH' and keys %$got == 2;
        return (0, 'missing "dupe_name" key') if not exists $got->{dupe_name};

        # we don't know which ref will keep its name and which will be renamed
        my ($other_key) = grep $_ ne 'dupe_name', keys %$got;
        return 1
          if (eq_deeply($got->{dupe_name}, {type => 'integer'})
          and eq_deeply($got->{$other_key}, {type => 'string'})
          and $other_key =~ qr/\bmore-bundle2_yaml-definitions_dupe_name-\w+$/)
          or (eq_deeply($got->{dupe_name}, {type => 'string'})
          and eq_deeply($got->{$other_key}, {type => 'integer'})
          and $other_key =~ qr/\bmore-bundle_yaml-definitions_dupe_name-\w+$/);
        return (0, 'uh oh, got: ' . (Test::More::explain($got))[0]);
      }),

      # begin i_contain_refs_to_same_named_definitions definition
      type       => 'object',
      properties => {
        foo =>
          {'$ref' => re(qr/^#\/definitions\/(dupe_name|more-bundle_yaml-.*)$/)},
        bar => {
          '$ref' => re(qr/^#\/definitions\/(dupe_name|more-bundle2_yaml-.*)$/)
        },
      },
    },
    'when encountering references that have the same root name, one is renamed',
  ],

  [
    'i_have_a_ref_with_the_same_name',
    {
      definitions => {i_have_a_ref_with_the_same_name => {type => 'string'}},

      # begin i_have_a_ref_with_the_same_name definition
      type       => 'object',
      properties => {
        name     => {type => 'string'},
        children => {
          type  => 'array',
          items => {'$ref' => '#/definitions/i_have_a_ref_with_the_same_name'},
          default => [],
        },
      },
    },
    'we can handle pulling in references that have the same root name as the top level name',
  ],

  [
    'i_am_a_ref_to_another_file',
    {
      definitions => {ref3 => {type => 'integer'}},

      # begin i_am_a_ref_to_another_file definition - which is actually
      # i_have_a_ref_to_the_first_filename
      type       => 'object',
      properties => {gotcha => {'$ref' => '#/definitions/ref3'}},
    },
    'find and resolve a reference that immediately leaps to another file',
  ],
);

my $draft7_validator = JSON::Validator->new->version(7);
$draft7_validator->schema('http://json-schema.org/draft-07/schema#');

my $bundler_validator = JSON::Validator->new;
$bundler_validator->load_and_validate_schema('t/spec/more-bundle.yaml',
  {schema => 'http://json-schema.org/draft-07/schema#'});

subtest $_->[2] => sub {
  my ($schema_name, $expected_output, $test_name) = @$_;

  my $got = $bundler_validator->bundle(
    {schema => $bundler_validator->get('/definitions/' . $schema_name)});

  cmp_deeply($got, $expected_output, 'extracted schema for ' . $schema_name)
    or diag 'got: ', explain($got);

  my @errors = $draft7_validator->validate($got);
  ok(!@errors, 'bundled schema conforms to the draft 7 spec');

  my $fresh_draft7_validator = JSON::Validator->new;
  $fresh_draft7_validator->load_and_validate_schema($got,
    {schema => 'http://json-schema.org/draft-07/schema#'});
  cmp_deeply(
    $fresh_draft7_validator->schema->data,
    $expected_output,
    'our generated schema does not lose any data when parsed again by a new validator',
  );
  }
  for @tests;

done_testing;
