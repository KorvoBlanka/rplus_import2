package Rplus::Model::MinionWorker;

use strict;

use base qw(Rplus::DB::Object);

__PACKAGE__->meta->setup(
    table   => 'minion_workers',

    columns => [
        id       => { type => 'bigserial', not_null => 1 },
        host     => { type => 'text', not_null => 1 },
        pid      => { type => 'integer', not_null => 1 },
        started  => { type => 'timestamp with time zone', default => 'now()', not_null => 1 },
        notified => { type => 'timestamp with time zone', default => 'now()', not_null => 1 },
        inbox    => { type => 'scalar', default => '[]' },
    ],

    primary_key_columns => [ 'id' ],

    allow_inline_column_values => 1,
);

1;

