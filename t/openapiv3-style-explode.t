use Mojo::Base -strict;
use JSON::Validator::Schema::OpenAPIv3;
use Test::More;

my $schema = JSON::Validator->new->schema('data://main/schema.json')->schema;

test('get /array/label{id}' => [{path => {id => '.3,4,5'}}, {id => [3, 4, 5]}], [{path => {id => '5'}}, {id => [5]}]);

test(
  'get /array/label/explode{id}',
  [{path => {id => '.3.4.5'}}, {id => [3, 4, 5]}],
  [{path => {id => '.5'}},     {id => [5]}],
);

test(
  'get /array/matrix{id}',
  [{path => {id => ';id=3,4,5'}}, {id => [3, 4, 5]}],
  [{path => {id => ';id=5'}},     {id => [5]}],
);

test(
  'get /array/matrix/explode{id}',
  [{path => {id => ';id=3;id=4;id=5'}}, {id => [3, 4, 5]}],
  [{path => {id => ';id=5'}},           {id => [5]}],
);

test(
  'get /array/query',
  [{},                                     {},                           '/ri: Missing property.'],
  [{query => {ri => '1.3'}},               {ri => 'ri'},                 '/ri/0: Expected integer - got string.'],
  [{query => {ml => 5, ri => '0'}},        {ml => 'ml', ri => [0]},      '/ml: Not enough items: 1/2.'],
  [{query => {ml => ['3', 5], ri => '0'}}, {ml => [3, 5], ri => [0]},    ''],
  [{query => {pi => '1|2|3', ri => '0'}},  {pi => [1, 2, 3], ri => [0]}, ''],
  [{query => {ri => '0', sp => '2 3 4'}},  {ri => [0], sp => [2, 3, 4]}, '']
);

test(
  'get /array/simple/{id}',
  [{}, {}, '/id: Missing property.'],
  [{path => {id => '10'}},    {id => [10]}],
  [{path => {id => '10,20'}}, {id => [10, 20]}]
);

test('get /object/label{id}',
  [{path => {id => '.category.bird.name.birdy'}}, {id => {category => 'bird', name => 'birdy'}}]);

test('get /object/label/explode{id}',
  [{path => {id => '.category=bird.name=birdy'}}, {id => {category => 'bird', name => 'birdy'}}]);

test('get /object/matrix{id}',
  [{path => {id => ';id=category,bird,name,birdy'}}, {id => {category => 'bird', name => 'birdy'}}]);

test('get /object/matrix/explode{id}',
  [{path => {id => ';category=bird;name=birdy'}}, {id => {category => 'bird', name => 'birdy'}}]);

test(
  'get /object/query',
  [{}, {}, ''],
  [{query => {ff => ''}},                 {all => {ff => ['']},                 ff => {}}],
  [{query => {pf => ''}},                 {all => {pf => ''},                   pf => {}}],
  [{query => {sf => ''}},                 {all => {sf => ''},                   sf => {}}],
  [{query => {ff => 'name,birdy,age,1'}}, {all => {ff => ['name,birdy,age,1']}, ff => {age => 1, name => 'birdy'}}],
  [{query => {pf => 'name|birdy|age|2'}}, {all => {pf => 'name|birdy|age|2'},   pf => {age => 2, name => 'birdy'}}],
  [{query => {sf => 'name birdy age 3'}}, {all => {sf => 'name birdy age 3'},   sf => {age => 3, name => 'birdy'}}],
);

test(
  'get /object/query',
  [
    {query => {'do[name]' => 'birdy', 'do[birth-date][gte]' => '1970-01-01', 'do[numbers][0]' => '5'}},
    {
      all => {'do[name]' => 'birdy', 'do[birth-date][gte]' => '1970-01-01',          'do[numbers][0]' => 5},
      do  => {name       => 'birdy', 'birth-date'          => {gte => '1970-01-01'}, numbers          => [5]},
    },
  ],
  [
    {query => {'do[0][1][0]' => 2, 'do[2][0]' => 4}},
    {all   => {'do[0][1][0]' => 2, 'do[2][0]' => 4}, do => {0 => [undef, [2]], 2 => [4]}},
  ],
  [
    {query => {'do[numbers][1]' => 2, 'do[numbers][0]' => '4'}},
    {all   => {'do[numbers][0]' => 4, 'do[numbers][1]' => 2}, do => {numbers => [4, 2]}},
  ],
  [{query => {'do[numbers][]' => [3, '5']}}, {all => {'do[numbers][]' => [3, 5]}, do => {numbers => [3, 5]}}],
  [{query => {'do[numbers]'   => [4, 6]}},   {all => {'do[numbers]'   => [4, 6]}, do => {numbers => [4, 6]}}],
);

test('get /object/simple/{id}',
  [{path => {id => 'category,bird,name,birdy'}}, {id => {category => 'bird', name => 'birdy'}}]);

test('get /object/simple/explode/{id}',
  [{path => {id => 'category=bird,name=birdy'}}, {id => {category => 'bird', name => 'birdy'}}]);

done_testing;

sub test {
  my ($path, @tests) = @_;

  subtest "path $path" => sub {
    for (@tests) {
      my ($input, $exp, $err) = @$_;
      my (%mutated, %req);

      for my $in (keys %$input) {
        $req{$in} = sub {
          my ($name, $param) = @_;
          return $mutated{$param->{name}}
            = defined $name
            ? {exists => exists $input->{$in}{$name}, value => $input->{$in}{$name}}
            : {exists => 1, value => {map { ($_ => $input->{$in}{$_}) } keys %{$input->{$in}}}};
        };
      }

      my @errors = $schema->validate_request([split ' ', $path], \%req);
      is "@errors", $err || '', sprintf 'validate %s', Mojo::JSON::to_json($exp);

      delete $mutated{$_} for grep { !defined $mutated{$_}{valid} } keys %mutated;
      $mutated{$_}{value} = $mutated{$_}{name}  for grep { !$mutated{$_}{valid} } keys %mutated;
      $mutated{$_}        = $mutated{$_}{value} for keys %mutated;
      is_deeply \%mutated, $exp, sprintf 'mutated %s', Mojo::JSON::to_json($exp);
    }
  };
}

__DATA__
@@ schema.json
{
  "openapi": "3.0.0",
  "info": { "title": "Style And Explode", "version": "" },
  "paths": {
    "/array/label{id}": {
      "get": {
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "style": "label",
            "explode": false,
            "schema": { "type": "array", "items": { "type": "integer" }, "minItems": 1 }
          }
        ]
      }
    },
    "/array/label/explode{id}": {
      "get": {
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "style": "label",
            "explode": true,
            "schema": { "type": "array", "items": { "type": "integer" }, "minItems": 1 }
          }
        ]
      }
    },
    "/array/matrix{id}": {
      "get": {
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "style": "matrix",
            "explode": false,
            "schema": { "type": "array", "items": { "type": "integer" }, "minItems": 1 }
          }
        ]
      }
    },
    "/array/matrix/explode{id}": {
      "get": {
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "style": "matrix",
            "explode": true,
            "schema": { "type": "array", "items": { "type": "integer" }, "minItems": 1 }
          }
        ]
      }
    },
    "/array/simple/{id}": {
      "get": {
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "style": "simple",
            "schema": { "type": "array", "items": { "type": "integer" }, "minItems": 1 }
          }
        ]
      }
    },
    "/array/query": {
      "get": {
        "parameters": [
          {
            "name": "ml",
            "in": "query",
            "style": "form",
            "explode": true,
            "schema": { "type": "array", "items": { "type": "string" }, "minItems": 2 }
          },
          {
            "name": "ri",
            "in": "query",
            "required": true,
            "style": "form",
            "explode": true,
            "schema": { "type": "array", "items": { "type": "integer" }, "minItems": 1 }
          },
          {
            "name": "sp",
            "in": "query",
            "style": "spaceDelimited",
            "schema": { "type": "array", "items": { "type": "integer" } }
          },
          {
            "name": "pi",
            "in": "query",
            "style": "pipeDelimited",
            "schema": { "type": "array", "items": { "type": "integer" } }
          }
        ]
      }
    },
    "/object/label{id}": {
      "get": {
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "style": "label",
            "explode": false,
            "schema": { "type": "object" }
          }
        ]
      }
    },
    "/object/label/explode{id}": {
      "get": {
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "style": "label",
            "explode": true,
            "schema": { "type": "object" }
          }
        ]
      }
    },
    "/object/matrix{id}": {
      "get": {
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "style": "matrix",
            "explode": false,
            "schema": { "type": "object" }
          }
        ]
      }
    },
    "/object/matrix/explode{id}": {
      "get": {
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "style": "matrix",
            "explode": true,
            "schema": { "type": "object" }
          }
        ]
      }
    },
    "/object/query": {
      "get": {
        "parameters": [
          {
            "name": "do",
            "in": "query",
            "style": "deepObject",
            "explode": true,
            "schema": { "type": "object" }
          },
          {
            "name": "ff",
            "in": "query",
            "style": "form",
            "explode": false,
            "schema": { "type": "object" }
          },
          {
            "name": "all",
            "in": "query",
            "style": "form",
            "explode": true,
            "schema": {
              "type": "object",
              "properties": {
                "ff": {"type": "array", "items": {"type": "string"}}
              }
            }
          },
          {
            "name": "sf",
            "in": "query",
            "style": "spaceDelimited",
            "explode": false,
            "schema": { "type": "object" }
          },
          {
            "name": "pf",
            "in": "query",
            "style": "pipeDelimited",
            "explode": false,
            "schema": { "type": "object" }
          }
        ]
      }
    },
    "/object/simple/{id}": {
      "get": {
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "style": "simple",
            "explode": false,
            "schema": { "type": "object" }
          }
        ]
      }
    },
    "/object/simple/explode/{id}": {
      "get": {
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "style": "simple",
            "explode": true,
            "schema": { "type": "object" }
          }
        ]
      }
    }
  }
}
