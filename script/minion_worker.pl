#!/usr/bin/env perl

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../lib" }

# outter modules
use Mojolicious::Lite;
use JSON;

# model
use Rplus::Model::Error::Manager;
use Rplus::Model::Lock::Manager;

use Rplus::Modern;
use Rplus::Import::QueueDispatcher;
use Rplus::Import::ItemDispatcher;

# tmp modules
use Data::Dumper;


plugin Minion => {Pg => 'postgresql://raven:raven!12345@localhost/rplus_import_dev'};

app->minion->add_task(enqueue_task => sub {
    my ($job, @args) = @_;
    my $media = $args[0]->{media};
    my $location = $args[0]->{location};
    my $category = $args[0]->{category};
    my $lock_code = $args[0]->{lock_code};

    my $lock = Rplus::Model::Lock::Manager->get_objects(query => [code => $lock_code])->[0];
    # it MUST be locked already, cannot die if not (cause we are in worker, and it will not show error if died)
    unless ($lock->state) {
        say 'WTF?!?!? not locked ' . $lock_code;
    }

    $lock->state(1);
    $lock->save;

    eval {
        Rplus::Import::QueueDispatcher::enqueue($media, $location, $category);
        1;
    } or do {
        my $m = {
            task => 'enqueue_task',
            task_arg => {
                media => $media,
                location => $location,
                category => $category
            },
            err_msg => $@
        };
        my $err = Rplus::Model::Error->new(metadata => to_json($m));
        $err->save;
    };

    # release lock
    $lock->state(0);
    $lock->save;
});

app->minion->add_task(load_item => sub {
    my ($job, @args) = @_;
    my $task = $args[0];

    eval {
        Rplus::Import::ItemDispatcher::load_item($task);
        1;
    } or do {
        my $m = {
            task => 'load_item',
            task_arg => $task,
            err_msg => $@
        };
        my $err = Rplus::Model::Error->new(metadata => to_json($m));
        $err->save;
        $job->fail('error ' . $err->id);
    };
});

app->start;
