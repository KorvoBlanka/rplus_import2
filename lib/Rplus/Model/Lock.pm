package Rplus::Model::Lock;

use strict;

use base qw(Rplus::DB::Object);

__PACKAGE__->meta->setup(
    table   => 'locks',

    columns => [
        id    => { type => 'serial', not_null => 1 },
        code  => { type => 'varchar', not_null => 1 },
        state => { type => 'boolean', default => 'false', not_null => 1 },
        ts    => { type => 'timestamp with time zone', default => 'now()', not_null => 1 },
    ],

    primary_key_columns => [ 'id' ],

    allow_inline_column_values => 1,
);

1;

