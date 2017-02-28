use Mojo::Base -strict;
use Test::More;
use JSON::Validator::OpenAPI;
use Data::Dumper;

#for my $i (1..20) {
my $validator = JSON::Validator::OpenAPI->new->load_and_validate_spec(
    't/spec/koha-swagger/swagger.json',
    {
        allow_invalid_ref => 1
    }
);

is(for_hash($validator->schema->{data}), 0, 'No $refs unresolved.');
#}

sub for_hash {
    my ($hash) = @_;
    while (my ($key, $value) = each %$hash) {
        if ('HASH' eq ref $value) {
            my $ret = for_hash($value);
            if ($ret) {
                return $ret;
            }
        }
        else {
            if ($key eq '$ref') {
                return $value;
            }
        }
    }
}

done_testing;
