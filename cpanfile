# You can install this projct with curl -L http://cpanmin.us | perl - https://github.com/jhthorsen/json-validator/archive/master.tar.gz
requires "Mojolicious" => "7.28";

recommends "Cpanel::JSON::XS"       => "3.02";
recommends "Data::Validate::Domain" => "0.10";
recommends "Data::Validate::IP"     => "0.24";
recommends "Mojo::JSON::MaybeXS"    => "0.01";
recommends "YAML::XS"               => "0.67";

test_requires "Test::More" => "1.30";
