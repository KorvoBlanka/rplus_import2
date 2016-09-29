#!/usr/bin/env perl

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../lib" }

# outter modules
use Mojolicious::Lite;

# model
use Rplus::Model::Lock::Manager;

use Rplus::Modern;
use Rplus::Import::QueueDispatcher;
use Rplus::Import::ItemDispatcher;

# tmp modules
use Data::Dumper;


plugin Minion => {Pg => 'postgresql://raven:PfBvgthfnjhf111@localhost/rplus_import_dev'};

app->minion->add_task(enqueue_task => sub {
    my ($job, @args) = @_;
    my $media = $args[0]->{media};
    my $location = $args[0]->{location};
    my $category = $args[0]->{category};
    my $lock_code = $args[0]->{lock_code};

    say 'enqueue_task';
    say $media;
    say $location;
    say $category;

    my $lock = Rplus::Model::Lock::Manager->get_objects(query => [code => $lock_code])->[0];
    # it MUST be locked already, cannot die if not (cause we are in worker, and it will not show error if died)
    unless ($lock) {
        say 'WTF?!?!? not locked ' . $lock_code;
    }

    $lock->state(1);
    $lock->save;

    eval {
        Rplus::Import::QueueDispatcher::enqueue($media, $location, $category);
        1;
    } or do {
        say 'ooops';
        say Dumper $@;
    };

    # release lock
    say 'release lock';
    $lock->state(0);
    $lock->save;


});

app->minion->add_task(load_item => sub {
    my ($job, @args) = @_;
    my $task = $args[0];

    say 'load_item';
    say Dumper $task;

    eval {
        Rplus::Import::ItemDispatcher::load_item($task);
        1;
    } or do {
        say 'ooops';
        say Dumper $@;
    };
});

app->start;
