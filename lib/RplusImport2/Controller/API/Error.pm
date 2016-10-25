package RplusImport2::Controller::API::Error;
use Mojo::Base 'Mojolicious::Controller';

use Rplus::DB;
use Rplus::Model::Error::Manager;

use Data::Dumper;

# This action will render a template

sub list {
    my $self = shift;

    my $page = $self->param('page') | 0;
    my $first_id = $self->param('first_id') | 0;
    my $per_page = 50;

    my $res = {
        list => [],
        count => 0
    };

    my $query = [];
    push @{$query}, id => {lt => $first_id} if $first_id;

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
        $res->{count} += 1;
        push @{$res->{list}}, $r;
    }

    $self->render(json => $res);
}

1;
