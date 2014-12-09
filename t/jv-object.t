use Mojo::Base -strict;
use Test::More;
use Swagger2::SchemaValidator;

my $validator = Swagger2::SchemaValidator->new;
my ($schema, @errors);

{
  $schema = {type => 'object'};
  @errors = $validator->validate({mynumber => 1}, $schema);
  is "@errors", "", "object";
  @errors = $validator->validate([1], $schema);
  is "@errors", "/: Expected object - got array.", "got array";
}

{
  $schema->{properties} = {
    number      => {type => "number"},
    street_name => {type => "string"},
    street_type => {type => "string", enum => ["Street", "Avenue", "Boulevard"]}
  };
  local $schema->{patternProperties} = {"^S_" => {type => "string"}, "^I_" => {type => "integer"}};

  @errors = $validator->validate({number => 1600, street_name => "Pennsylvania", street_type => "Avenue"}, $schema);
  is "@errors", "", "object with properties";
  @errors = $validator->validate({number => "1600", street_name => "Pennsylvania", street_type => "Avenue"}, $schema);
  is "@errors", "/number: Expected number - got string.", "object with invalid number";
  @errors = $validator->validate({number => 1600, street_name => "Pennsylvania"}, $schema);
  is "@errors", "", "object with missing properties";
  @errors
    = $validator->validate({number => 1600, street_name => "Pennsylvania", street_type => "Avenue", direction => "NW"},
    $schema);
  is "@errors", "", "object with additional properties";

  @errors = $validator->validate({"S_25" => "This is a string", "I_0" => 42}, $schema);
  is "@errors", "", "S_25 I_0";
  @errors = $validator->validate({"S_0" => 42}, $schema);
  is "@errors", "/S_0: Expected string - got number.", "S_0";
}

{
  local $schema->{additionalProperties} = 0;
  @errors
    = $validator->validate({number => 1600, street_name => "Pennsylvania", street_type => "Avenue", direction => "NW"},
    $schema);
  is "@errors", "/: Properties not allowed: direction.", "additionalProperties=0";

  $schema->{additionalProperties} = {type => "string"};
  @errors
    = $validator->validate({number => 1600, street_name => "Pennsylvania", street_type => "Avenue", direction => "NW"},
    $schema);
  is "@errors", "", "additionalProperties=object";
}

{
  local $schema->{required} = ["number", "street_name"];
  @errors = $validator->validate({number => 1600, street_type => "Avenue"}, $schema);
  is "@errors", "/street_name: Missing property.", "object with required";
}

{
  $schema = {type => 'object', minProperties => 2, maxProperties => 3,};
  @errors = $validator->validate({a => 1}, $schema);
  is "@errors", "/: Not enough properties: 1/2.", "not enough properties";
  @errors = $validator->validate({a => 1, b => 2}, $schema);
  is "@errors", "", "object with required";
  @errors = $validator->validate({a => 1, b => 2, c => 3, d => 4}, $schema);
  is "@errors", "/: Too many properties: 4/3.", "too many properties";
}

{
  local $TODO = 'Add support for dependencies';
  $schema = {
    type => "object",
    properties =>
      {name => {type => "string"}, credit_card => {type => "number"}, billing_address => {type => "string"}},
    required     => ["name"],
    dependencies => {credit_card => ["billing_address"]}
  };

  @errors = $validator->validate({name => "John Doe", credit_card => 5555555555555555}, $schema);
  is "@errors", "/credit_card: Missing billing_address.", "credit_card";
}

done_testing;
