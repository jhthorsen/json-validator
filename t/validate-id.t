  use lib '.';
  use t::Helper;

  validate_ok {id => 1}, {type => 'object'};

  validate_ok {id => 1, message => 'cannot exclude "id" #111'},
    {
    type                 => 'object',
    additionalProperties => 0,
    properties           => {message => {type => "string"}}
    },
    E('/', 'Properties not allowed: id.');

  done_testing;
