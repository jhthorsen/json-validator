use strict;
use Test::More;

BEGIN { use_ok ('JSON::Validator::Formats'); }

ok !JSON::Validator::Formats::check_date('2019-06-11');
ok !JSON::Validator::Formats::check_email('doe@example.org');
ok !JSON::Validator::Formats::check_time('08:22:54');

done_testing;
