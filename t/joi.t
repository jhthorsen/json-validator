use lib '.';
use t::Helper;
use JSON::Validator 'joi';
use Test::More;

is_deeply(
  edj(joi->object->strict->props(
    age       => joi->integer->min(0)->max(200),
    alphanum  => joi->alphanum->length(12),
    color     => joi->string->min(2)->max(12)->pattern('^\w+$'),
    date_time => joi->iso_date,
    email     => joi->string->email->required,
    exists    => joi->boolean,
    lc        => joi->lowercase,
    name      => joi->string->min(1),
    pos       => joi->positive,
    token     => joi->token,
    uc        => joi->uppercase,
    uri       => joi->uri,
  )),
  {
    type       => 'object',
    required   => ['email'],
    properties => {
      age      => {type => 'integer', minimum => 0, maximum => 200},
      alphanum => {
        type      => 'string',
        minLength => 12,
        maxLength => 12,
        pattern   => '^\w*$'
      },
      color =>
        {type => 'string', minLength => 2, maxLength => 12, pattern => '^\w+$'},
      date_time => {type => 'string', format    => 'date-time'},
      email     => {type => 'string', format    => 'email'},
      exists    => {type => 'boolean'},
      lc        => {type => 'string', pattern   => '^\p{Lowercase}*$'},
      name      => {type => 'string', minLength => 1},
      pos       => {type => 'number', minimum   => 0},
      token     => {type => 'string', pattern   => '^[a-zA-Z0-9_]+$'},
      uc        => {type => 'string', pattern   => '^\p{Uppercase}*$'},
      uri       => {type => 'string', format    => 'uri'},
    },
    additionalProperties => false
  },
  'generated correct object schema'
);

is_deeply(
  edj(joi->array->min(0)->max(10)->strict->items(joi->integer->negative)),
  {
    additionalItems => false,
    type            => 'array',
    minItems        => 0,
    maxItems        => 10,
    items           => {type => 'integer', maximum => 0}
  },
  'generated correct array schema'
);

is_deeply(
  edj(joi->string->enum([qw(1.0 2.0)])),
  {type => 'string', enum => [qw(1.0 2.0)]},
  'enum for string'
);

is_deeply(
  edj(joi->integer->enum([qw(1 2 4 8 16)])),
  {type => 'integer', enum => [qw(1 2 4 8 16)]},
  'enum for integer'
);

joi_ok(
  {age => 34, email => 'jhthorsen@cpan.org', name => 'Jan Henning Thorsen'},
  joi->props(
    age   => joi->integer->min(0)->max(200),
    email => joi->string->email->required,
    name  => joi->string->min(1),
  ),
);

joi_ok(
  {age => -1, name => 'Jan Henning Thorsen'},
  joi->props(
    age   => joi->integer->min(0)->max(200),
    email => joi->string->email->required,
    name  => joi->string->min(1),
  ),
  E('/age',   '-1 < minimum(0)'),
  E('/email', 'Missing property.'),
);

eval { joi->number->extend(joi->integer) };
like $@, qr{Cannot extend joi 'number' by 'integer'},
  'need to extend same type';

is_deeply(
  edj(joi->array->min(0)->max(10)->extend(joi->array->min(5))),
  {type => 'array', minItems => 5, maxItems => 10},
  'extended array',
);

is_deeply(
  edj(joi->integer->min(0)->max(10)->extend(joi->integer->min(5))),
  {type => 'integer', minimum => 5, maximum => 10},
  'extended integer',
);

is_deeply(
  edj(
    joi->object->props(x => joi->integer, y => joi->integer)
      ->extend(joi->object->props(x => joi->number))
  ),
  {
    type       => 'object',
    properties => {x => {type => 'number'}, y => {type => 'integer'}}
  },
  'extended object',
);

is_deeply(
  edj(joi->object->props(
    ip => joi->type([qw(string null)])->format('ip'),
    ns => joi->string
  )),
  {
    type       => 'object',
    properties => {
      ip => {format => 'ip', type => [qw(string null)]},
      ns => {type   => 'string'},
    }
  },
  'null or string',
);

done_testing;
