package RplusImport2::Controller::API::Statistic;
use Mojo::Base 'Mojolicious::Controller';

use Rplus::DB;
use Rplus::Model::MinionJob::Manager;

use Rplus::Util::Config qw(get_config);

use Data::Dumper;

# This action will render a template

sub get {
    my $self = shift;

    my $task_type = $self->param('task_type');
    my $media = $self->param('media') || 'all';
    my $location = $self->param('location') || 'all';

    my @query = ();

    my $res = {
        data => {},
    };

    push @query, "mj.args->0->>'media' = '$media'" unless ($media eq 'all');
    push @query, "mj.args->0->>'location' = '$location'" unless ($location eq 'all');
    push @query, "task = '$task_type'";
    #my $err_iter = Rplus::Model::MinionJob::Manager->get_objects_iterator(query => $query,
    #    page => $page,
    #    per_page => $per_page,
    #    sort_by => 'id DESC'
    #);

    my $dbh = Rplus::DB->new_or_cached->dbh;
    my @states = ('failed', 'finished', 'active', 'inactive');

    foreach my $state (@states) {
        my $query_str = join ' AND ', @query;

        my $t1 = $dbh->selectall_arrayref(
            "SELECT COUNT(id)
            FROM minion_jobs mj
            WHERE " . $query_str . " AND state = '$state'"
        );

        my $ts = 'finished';
        if ($state eq 'inactive') {
            $ts = 'created';
        } elsif ($state eq 'active') {
            $ts = 'started';
        }

        my $t2 = $dbh->selectall_arrayref(
            "SELECT COUNT(id)
            FROM minion_jobs mj
            WHERE " . $query_str . " AND state = '$state'
            AND mj.$ts >= now() - INTERVAL '1h'"
        );
        $res->{data}->{$state} = {
            count => $t1->[0]->[0] * 1,
            count_1h => $t2->[0]->[0] * 1
        };
    }

    $self->render(json => $res);
}

sub get_active {
    my $self = shift;

    my $res = {
        list => [],
        count => 0
    };

    my $rec_iter = Rplus::Model::MinionJob::Manager->get_objects_iterator(
        query => [
            state => 'active'
        ],
        sort_by => 'id DESC'
    );

    while(my $rec = $rec_iter->next) {
        my $r = {
            id => $rec->id,
            args => $rec->args,
            created => $rec->created,
            started => $rec->started,
            task => $rec->task,
            queue => $rec->queue,
            retries => $rec->retries
        };
        $res->{count} ++;
        push @{$res->{list}}, $r;
    }

    $self->render(json => $res);
}

1;
