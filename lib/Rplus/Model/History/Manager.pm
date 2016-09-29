package Rplus::Model::History::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);

use Rplus::Model::History;

sub object_class { 'Rplus::Model::History' }

__PACKAGE__->make_manager_methods('history');

1;

