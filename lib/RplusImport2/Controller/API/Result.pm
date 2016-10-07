package RplusImport2::Controller::API::Result;
use Mojo::Base 'Mojolicious::Controller';

use Rplus::DB;
use Rplus::Model::Result::Manager;

use Data::Dumper;

# This action will render a template
sub get {
    my $self = shift;

    my $media = $self->param('media') || 'any';
    my $location = $self->param('location');
    my $page = $self->param('page') || 0;
    my $per_page = 50;
    my $first_id = $self->param('first_id') || 0;
    my $last_id = $self->param('last_id') || 0;

    return $self->render(json => {error => 'Bad Request'}, status => 400) unless $location;

    my $list = {
        list => [],
        count => 0,
    };

    my @query;
    {
        push @query, location => $location;
        push @query, media => $media if ($media ne 'any');
        push @query, id => {lt => $first_id} if $first_id;
        push @query, id => {gt => $last_id} if $last_id;
    }

    my $iter = Rplus::Model::Result::Manager->get_objects_iterator(query => [
            @query
        ],
        page => $page,
        per_page => $per_page,
        sort_by => 'id DESC'
    );

    while(my $result = $iter->next) {
        my $r = {
            id => $result->id,
            data => $result->metadata
        };
        $list->{count} += 1;
        push @{$list->{list}}, $r;
    }

    $self->render(json => $list);
}

sub get_summary {
    my $self = shift;

    my $location = $self->param('location');
    my $last_id = $self->param('last_id');
    return $self->render(json => {error => 'Bad Request'}, status => 400) unless $location;

    my $r = Rplus::DB->new_or_cached->dbh->selectall_arrayref("SELECT max(id) FROM results WHERE location = '$location'");

    my $x = {
        max_id => $r->[0]->[0],
        #count
    };

    $self->render(json => {bla => 'bla'});
}

1;
