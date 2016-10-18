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
use Rplus::Util::Config;


use Data::Dumper;

no warnings 'experimental';

# This method will run once at server start
sub startup {
    my $self = shift;

    # Plugins
    # Documentation browser under "/perldoc"
    #$self->plugin('PODRenderer');
    my $config = $self->plugin('Config' => {file => 'app.conf'});

    my $minion = Minion->new(Pg => 'postgresql://raven:raven!12345@localhost/rplus_import_dev');

    say '<<<<<<<<<<------------------------------------------------->>>>>>>>>>';

    #$minion->reset;
    say Dumper $minion->stats;


    # Router
    my $r = $self->routes;

    # Normal route to controller
    #$r->get('/')->to('example#welcome');
    $r->get('/')->to(template => 'main/index');

    # API namespace
    $r->route('/api/:controller/:action')->to(namespace => 'RplusImport2::Controller::API');

    #Rplus::Import::QueueDispatcher::enqueue('present_site', 'khv', '/present/notice/index/rubric/kvartiry-prodaja/');
    #Rplus::Import::QueueDispatcher::enqueue('mkv', 'khv', 'http://www.mirkvartir.ru/Хабаровский+край/Хабаровск/Комнаты/');
    #Rplus::Import::QueueDispatcher::enqueue('bn', 'msk', '/sale/city/flats/');
    #Rplus::Import::QueueDispatcher::enqueue('avito', 'khv', '/habarovsk/kvartiry/sdam');
    #Rplus::Import::QueueDispatcher::enqueue('irrru', 'khv', '/real-estate/rooms-sale/');
    #Rplus::Import::QueueDispatcher::enqueue('farpost', 'khv', '/khabarovsk/realty/sell_flats/');
    #Rplus::Import::QueueDispatcher::enqueue('cian', 'msk', '/kupit-1-komnatnuyu-kvartiru/');
    #Rplus::Import::QueueDispatcher::enqueue('barahlo', 'khv', '/realty/217/1/');
    #Rplus::Import::QueueDispatcher::enqueue('vnh', 'khv');
    #Rplus::Import::QueueDispatcher::enqueue('bnspb', 'spb', '/zap_fl.phtml');


    #Rplus::Import::ItemDispatcher::load_item({
    #    media => 'bnspb',
    #    location => 'spb',
    #    url => '/detail/flats/1188440.html'
    #});

    #Rplus::Import::ItemDispatcher::load_item({
    #    media => 'vnh',
    #    location => 'khv',
    #    url => '/declare/1461253'
    #});

    #Rplus::Import::ItemDispatcher::load_item({
    #    media => 'barahlo',
    #    location => 'khv',
    #    url => 'http://habarovsk.barahla.net/realty/217/8493651.html'
    #q});

    #Rplus::Import::ItemDispatcher::load_item({
    #    media => 'present_site',
    #    location => 'khv',
    #    url => '/present/notice/view/3473868'
    #});

    #Rplus::Import::ItemDispatcher::load_item({
    #    media => 'mkv',
    #    location => 'khv',
    #    url => 'http://www.mirkvartir.ru/165979341/'
    #});

    #Rplus::Import::ItemDispatcher::load_item({
    #    media => 'bn',
    #    location => 'msk',
    #    url => '/sale/city/flats/26497952/'
    #});

    #Rplus::Import::ItemDispatcher::load_item({
    #    media => 'cian',
    #    location => 'msk',
    #    url => 'http://www.cian.ru/sale/flat/149964608/'
    #});

    #Rplus::Import::ItemDispatcher::load_item({
    #    media => 'irr',
    #    location => 'khv',
    #    url => 'http://khabarovsk.irr.ru/real-estate/apartments-sale/secondary/1-komn-kvartira-leningradskaya-ul-13-advert607212202.html'
    #});

    #Rplus::Import::ItemDispatcher::load_item({
    #    media => 'farpost',
    #    location => 'khv',
    #    url => '/khabarovsk/realty/sell_flats/2k-juzhnyj-44751144.html'
    #});

    #Rplus::Import::ItemDispatcher::load_item({
    #    media => 'avito',
    #    location => 'khv',
    #    url => '/habarovsk/kvartiry/3-k_kvartira_82.4_m_725_et._844345679'
    #});


    if (1) {
        my $timer_id_1 = Mojo::IOLoop->recurring(1 => sub {
            # buisy lock
            my $lock = Rplus::Model::Lock::Manager->get_objects(query => [code => 'tasks_cycle'])->[0];
            unless ($lock->state) {
                $lock->state(1);
                $lock->save;
                # check if we have a new task_process
                my $task_iter = Rplus::Model::Task::Manager->get_objects_iterator(query => [delete_ts => undef]);
                while (my $task = $task_iter->next) {
                    my $q_name = $task->media;
                    say 'enqueue task ' . $task->media . '-' . $task->location . '-' . $task->url;

                    $minion->enqueue(
                        load_item => [
                            {media => $task->media, location => $task->location, url => $task->url}
                        ], {
                            priority => 10,
                            queue => $q_name,
                        }
                    );
                    $task->delete_ts('now()');
                    $task->save;
                }
                $lock->state(0);
                $lock->save;
            }
        });

        my $timer_id_2 = Mojo::IOLoop->recurring(30 => sub {
            my $load_list = Rplus::Util::Config::get_config('load_list')->{load_list};
            foreach my $mname (keys %{$load_list}) {
                my $loc_list = $load_list->{$mname};
                foreach my $lname (@$loc_list) {
                    my $mc = Rplus::Class::Media->instance();
                    my $media_data = $mc->get_media($mname, $lname);

                    foreach (@{$media_data->{source_list}}) {
                        my $category = $_->{url};
                        my $lock_code = $mname . '-' . $lname . '-' . $category;

                        my $lock = Rplus::Model::Lock::Manager->get_objects(query => [code => $lock_code])->[0];
                        unless ($lock) {
                            $lock = Rplus::Model::Lock->new(code => $lock_code);
                            $lock->save;
                        }
                        # unless lock

                        unless ($lock->state) {
                            say 'enqueue enq task ' . $lock_code;
                            # aq lock and enq task, task will release lock upon completion
                            $lock->state(1);
                            $lock->save;
                            $minion->enqueue(enqueue_task => [{media => $mname, location => $lname, category => $category, lock_code => $lock_code}]);
                        }
                    }
                }
            }
        });
    }
}

1;
