package Rplus::Model::Lock::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Rplus::Model::Lock;

sub object_class { 'Rplus::Model::Lock' }

__PACKAGE__->make_manager_methods('locks');

1;

