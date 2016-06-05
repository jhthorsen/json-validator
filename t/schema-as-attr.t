use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

my $json = JSON::Validator->new;
my $schema;

no warnings 'redefine';
*JSON::Validator::_validate = sub { $schema = shift->schema };
$json->validate({data => 1}, {type => 'object'});
is_deeply $schema->data, {type => 'object'}, 'schema() localized';
is $json->schema, undef, 'schema() is not set';

done_testing;
