package t::test::number;
use t::Helper;

sub basic {
  schema_validate_ok 1, {type => 'number'};
}

sub maximum {
  schema_validate_ok 0, {maximum => 0};
  schema_validate_ok 1, {maximum => 1};
  schema_validate_ok - 1, {maximum => -2}, E('/', '-1 > maximum(-2)');
}

sub minimum {
  schema_validate_ok 0, {minimum => 0};
  schema_validate_ok 1, {minimum => 1};
  schema_validate_ok - 2, {minimum => -1}, E('/', '-2 < minimum(-1)');
}

1;
