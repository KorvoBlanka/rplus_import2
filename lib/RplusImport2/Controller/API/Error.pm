package RplusImport2::Controller::API::Error;
use Mojo::Base 'Mojolicious::Controller';

use Rplus::DB;
use Rplus::Model::Error::Manager;

use Data::Dumper;

# This action will render a template

sub list {
    my $self = shift;

    my $page = $self->param('page');
    my $first_id = $self->param('first_id');
    my $per_page = 50;

    my $task_type = $self->param('task_type') || 'all';
    my $media = $self->param('media') || 'all';
    my $location = $self->param('location') || 'all';


    my $query = [];
    push @{$query}, id => {lt => $first_id} if $first_id;
    push @{$query}, task_type => $task_type if $task_type ne 'all';
    push @{$query}, media => $media if $media ne 'all';
    push @{$query}, location => $location if $location ne 'all';

    my $res = {
        list => [],
        count => Rplus::Model::Error::Manager->get_objects_count(query => $query)
    };

    my $err_iter = Rplus::Model::Error::Manager->get_objects_iterator(query => $query,
        page => $page,
        per_page => $per_page,
        sort_by => 'id DESC'
    );

    while(my $err = $err_iter->next) {
        my $r = {
            id => $err->id,
            ts => $err->ts,
            task_type => $err->task_type,
            media => $err->media,
            location => $err->location,
            message => $err->message,
            metadata => $err->metadata
        };
        push @{$res->{list}}, $r;
    }

    $self->render(json => $res);
}

1;
