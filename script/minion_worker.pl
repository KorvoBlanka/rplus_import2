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


plugin Minion => {Pg => 'postgresql://raven:raven!12345@localhost/rplus_import'};

app->minion->add_task(enqueue_task => sub {
    my ($job, @args) = @_;
    my $media = $args[0]->{media};
    my $location = $args[0]->{location};
    my $category = $args[0]->{category};
    my $lock_code = $args[0]->{lock_code};


    eval {
        Rplus::Import::QueueDispatcher::enqueue($media, $location, $category);
        1;
    } or do {
        my $err_msg = $@;

        my $err = Rplus::Model::Error->new (
            task_type => 'enqueue_task',
            media => $media,
            location => $location,
            message => $err_msg,
            metadata => to_json({category => $category})
        );
        $err->save;
        $job->fail('error ' . $err->id);
        #$job->retry({delay => 60});
    };
});

app->minion->add_task(load_item => sub {
    my ($job, @args) = @_;
    my $task = $args[0];

    eval {
        Rplus::Import::ItemDispatcher::load_item($task);
        1;
    } or do {
        my $err_msg = $@;

        my $err = Rplus::Model::Error->new(
            task_type => 'load_item',
            media => $task->{media},
            location => $task->{location},
            message => $err_msg,
            metadata => to_json($task)
        );
        $err->save;
        $job->fail('error ' . $err->id);
        #$job->retry({delay => 60});
    };
});

app->start;
