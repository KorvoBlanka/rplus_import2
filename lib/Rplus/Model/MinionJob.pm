package Rplus::Model::MinionJob;

use strict;

use base qw(Rplus::DB::Object);

__PACKAGE__->meta->setup(
    table   => 'minion_jobs',

    columns => [
        id       => { type => 'bigserial', not_null => 1 },
        args     => { type => 'scalar', not_null => 1 },
        created  => { type => 'timestamp with time zone', default => 'now()', not_null => 1 },
        delayed  => { type => 'timestamp with time zone', not_null => 1 },
        finished => { type => 'timestamp with time zone' },
        priority => { type => 'integer', not_null => 1 },
        result   => { type => 'scalar' },
        retried  => { type => 'timestamp with time zone' },
        retries  => { type => 'integer', default => '0', not_null => 1 },
        started  => { type => 'timestamp with time zone' },
        state    => { type => 'enum', check_in => [ 'inactive', 'active', 'failed', 'finished' ], db_type => 'minion_state', default => 'inactive', not_null => 1 },
        task     => { type => 'text', not_null => 1 },
        worker   => { type => 'bigint' },
        queue    => { type => 'text', default => 'default', not_null => 1 },
        attempts => { type => 'integer', default => 1, not_null => 1 },
        parents  => { type => 'array', default => '{}' },
    ],

    primary_key_columns => [ 'id' ],

    allow_inline_column_values => 1,
);

1;

