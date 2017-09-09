package RplusImport2;
use Mojo::Base 'Mojolicious';
use Minion;

use Mojo::IOLoop;
use Rplus::Modern;
use Rplus::Class::Media;
use Rplus::Model::Task::Manager;

use Rplus::Import::QueueDispatcher;
use Rplus::Import::ItemDispatcher;
use Rplus::Util::Config qw(get_config);
use URI::Encode qw(uri_encode uri_decode);

use Data::Dumper;

no warnings 'experimental';

# This method will run once at server start
sub startup {
    my $self = shift;

    # Plugins
    # Documentation browser under "/perldoc"
    #$self->plugin('PODRenderer');
    my $config = $self->plugin('Config' => {file => 'app.conf'});

    my $minion = Minion->new(Pg => 'postgresql://raven:raven!12345@localhost/rplus_import');

    say '<<<<<<<<<<------------------------------------------------->>>>>>>>>>';

    #$minion->reset;
    say Dumper $minion->stats;

    $minion->backoff(sub {return 300;});

    # Router
    my $r = $self->routes;

    # Normal route to controller
    #$r->get('/')->to('example#welcome');
    $r->get('/')->to(template => 'main/index');
    $r->get('/:controller/:action')->to(action => 'index');

    # API namespace
    $r->route('/api/:controller/:action')->to(namespace => 'RplusImport2::Controller::API');

    #Rplus::Import::QueueDispatcher::enqueue('present_site', 'khv', '/present/notice/index/rubric/kvartiry-prodaja/');
    #Rplus::Import::QueueDispatcher::enqueue('mkv', 'khv', 'http://www.mirkvartir.ru/Хабаровский+край/Хабаровск/Комнаты/');
    #Rplus::Import::QueueDispatcher::enqueue('mkv', 'khv', 'http://arenda.mirkvartir.ru/Хабаровский+край/Хабаровск/');

        #Rplus::Import::QueueDispatcher::enqueue('bn', 'msk', '/sale/city/flats/');
    #Rplus::Import::QueueDispatcher::enqueue('avito', 'khv', '/habarovsk/kvartiry/prodam');

    #Rplus::Import::QueueDispatcher::enqueue('avito', 'khv', '/habarovsk/kvartiry/prodam');
    #Rplus::Import::QueueDispatcher::enqueue('avito', 'khv', '/habarovsk/komnaty/prodam');
    #Rplus::Import::QueueDispatcher::enqueue('avito', 'khv', '/habarovsk/doma_dachi_kottedzhi/prodam');
    #Rplus::Import::QueueDispatcher::enqueue('avito', 'khv', '/habarovsk/zemelnye_uchastki/prodam');
    #Rplus::Import::QueueDispatcher::enqueue('avito', 'khv', '/habarovsk/kommercheskaya_nedvizhimost/prodam');


    #Rplus::Import::QueueDispatcher::enqueue('irrru', 'khv', '/real-estate/apartments-sale/');
    #Rplus::Import::QueueDispatcher::enqueue('farpost', 'khv', '/khabarovsk/realty/sell_flats/');
    #Rplus::Import::QueueDispatcher::enqueue('cian', 'msk', '/snyat-1-komnatnuyu-kvartiru/');
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
    #    url => 'http://arenda.mirkvartir.ru/176605200/'
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
    #    location => 'kja',
    #    url => '/krasnoyarsk/komnaty/komnata_12_m_v_1-k_79_et._773986281'
    #    #url => '/habarovsk/kvartiry/2-k_kvartira_50_m_29_et._863465287'
    #});

    if (0) {
        my $medias = get_config('medias')->{media_list};
        foreach my $media_name (keys %{$medias}) {
            my $locations = $medias->{$media_name};
            foreach my $location_name (keys %{$locations}) {
                my $conf = $locations->{$location_name};
                foreach (@{$conf->{source_list}}) {
                    say $media_name . ' ' . $location_name;
                    say $_->{url};
                    Rplus::Import::QueueDispatcher::enqueue($media_name, $location_name, $_->{url});
                }
            }
        }
    }

    if (1) {
        my $timer_id_2 = Mojo::IOLoop->recurring(1800 => sub {
            my $load_list = get_config('load_list')->{load_list};
            foreach my $mname (keys %{$load_list}) {
                my $loc_list = $load_list->{$mname};

                # check queue if its empty - enq tasks
                # but we can lost some adv so fck it
                #my $rec_count = Rplus::Model::MinionJob::Manager->get_objects_count(
                #    query => [
                #        state => 'inactive',
                #        task => 'load_item',
                #        queue => $mname,
                #    ],
                #);
                #if ($rec_count < $TASK_LIMIT) {
                    foreach my $lname (@$loc_list) {
                        my $mc = Rplus::Class::Media->instance();
                        my $media_data = $mc->get_media($mname, $lname);

                        foreach (@{$media_data->{source_list}}) {
                            my $category = $_->{url};

                            say 'enqueue enq task ' . $mname . ' - ' . $lname . ' - ' . $category;

                            $minion->enqueue(
                                enqueue_task => [
                                    {media => $mname, location => $lname, category => $category}
                                ], {
                                    attempts => 3,
                                    priority => 10,
                                    queue => $mname,
                                }
                            );

                        }
                    }
                #}
            }
        });
    }
}

1;
