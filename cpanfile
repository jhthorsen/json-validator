# You can install this projct with curl -L http://cpanmin.us | perl - https://github.com/jhthorsen/swagger2/archive/master.tar.gz
requires "JSON::Validator" => "0.74";
requires "Mojolicious"     => "6.00";

recommends "Data::Validate::Domain" => "0.10";
recommends "Data::Validate::IP"     => "0.24";

test_requires "Test::More"     => "0.88";
test_requires "Test::Warnings" => "0.016";
