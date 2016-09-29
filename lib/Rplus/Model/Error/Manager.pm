package Rplus::Model::Error::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Rplus::Model::Error;

sub object_class { 'Rplus::Model::Error' }

__PACKAGE__->make_manager_methods('errors');

1;

