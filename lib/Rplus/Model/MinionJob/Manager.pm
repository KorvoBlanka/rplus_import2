package Rplus::Model::MinionJob::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Rplus::Model::MinionJob;

sub object_class { 'Rplus::Model::MinionJob' }

__PACKAGE__->make_manager_methods('minion_jobs');

1;

