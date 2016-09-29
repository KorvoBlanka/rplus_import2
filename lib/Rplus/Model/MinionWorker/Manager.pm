package Rplus::Model::MinionWorker::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Rplus::Model::MinionWorker;

sub object_class { 'Rplus::Model::MinionWorker' }

__PACKAGE__->make_manager_methods('minion_workers');

1;

