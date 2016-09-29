package RplusImport2;
use Mojo::Base 'Mojolicious';
use Minion;

use Mojo::IOLoop;
use Rplus::Modern;
use Rplus::Class::Media;
use Rplus::Model::Lock::Manager;
use Rplus::Model::Task::Manager;
use Rplus::Import::QueueDispatcher;
use Rplus::Import::ItemDispatcher;

use Data::Dumper;

no warnings 'experimental';

# This method will run once at server start
sub startup {
    my $self = shift;

    # Plugins
    # Documentation browser under "/perldoc"
    #$self->plugin('PODRenderer');
    my $config = $self->plugin('Config' => {file => 'app.conf'});

    my $minion = Minion->new(Pg => 'postgresql://raven:PfBvgthfnjhf111@localhost/rplus_import_dev');

    #say $minion->reset;
    say Dumper $minion->stats;


    # Router
    my $r = $self->routes;

    # Normal route to controller
    #$r->get('/')->to('example#welcome');
    $r->get('/')->to(template => 'main/index');

    # API namespace
    $r->route('/api/:controller/:action')->to(namespace => 'RplusImport2::Controller::API');

    Rplus::Import::Item::Avito::get_item('khv', '/habarovsk/zemelnye_uchastki/uchastok_15_sot._snt_dnp_640947102');
    #Rplus::Import::QueueDispatcher::enqueue('avito', 'khv');

    if (0) {
        my $timer_id_1 = Mojo::IOLoop->recurring(1 => sub {
            # buisy lock
            my $lock = Rplus::Model::Lock::Manager->get_objects(query => [code => 'tasks_cycle'])->[0];
            unless ($lock->state) {
                $lock->state(1);
                $lock->save;
                # check if we have a new task_process
                my $task_iter = Rplus::Model::Task::Manager->get_objects_iterator(query => [delete_ts => undef]);
                while (my $task = $task_iter->next) {
                    say 'enqueue task';

                    $minion->enqueue(load_item => [{media => $task->media, location => $task->location, url => $task->url}]);
                    $task->delete_ts('now()');
                    $task->save;
                }
                $lock->state(0);
                $lock->save;
            }
        });

        my $timer_id_2 = Mojo::IOLoop->recurring(1 => sub {
            my $media;
            my $location;
            my $category;
            foreach (@{['avito']}) {
                $media = $_;
                foreach (@{['khv']}) {
                    $location = $_;
                    my $mc = Rplus::Class::Media->instance();
                    my $media_data = $mc->get_media($media, $location);

                    foreach (@{$media_data->{source_list}}) {
                        $category = $_->{url};

                        my $lock_code = $media . '-' . $location . '-' . $category;
                        my $lock = Rplus::Model::Lock::Manager->get_objects(query => [code => $lock_code])->[0];
                        unless ($lock) {
                            $lock = Rplus::Model::Lock->new(code => $lock_code);
                            $lock->save;
                        }
                        # unless lock

                        unless ($lock->state) {
                            say 'enqueue enq task';
                            # aq lock and enq task, task will release lock upon completion
                            $lock->state(1);
                            $lock->save;
                            $minion->enqueue(enqueue_task => [{media => $media, location => $location, category => $category, lock_code => $lock_code}]);
                        }
                    }
                }
            }
        });
    }
}

1;
