package Rplus::Model::Error;

use strict;

use base qw(Rplus::DB::Object);

__PACKAGE__->meta->setup(
    table   => 'errors',

    columns => [
        id       => { type => 'serial', not_null => 1 },
        ts       => { type => 'timestamp with time zone', default => 'now()', not_null => 1 },
        metadata => { type => 'scalar', not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],

    allow_inline_column_values => 1,
);

1;

