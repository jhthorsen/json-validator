# You can install this projct with curl -L http://cpanmin.us | perl - https://github.com/jhthorsen/json-validator/archive/master.tar.gz
requires "Mojolicious" => "6.00";
requires "Mojo::JSON::MaybeXS" => "";
requires "Cpanel::JSON::XS" => "";

recommends "Data::Validate::Domain" => "0.10";
recommends "Data::Validate::IP"     => "0.24";
recommends "YAML::XS"               => "0.59";

test_requires "Test::More"     => "0.88";
test_requires "Test::Warnings" => "0.016";
