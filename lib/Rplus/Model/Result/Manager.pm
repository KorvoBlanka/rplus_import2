package Rplus::Model::Result::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Rplus::Model::Result;

sub object_class { 'Rplus::Model::Result' }

__PACKAGE__->make_manager_methods('results');

1;

