package Rplus::Import::Queue::BN;

use DateTime::Format::Strptime;

use Rplus::Modern;
use Rplus::Class::Media;
use Rplus::Class::Interface;
use Rplus::Class::UserAgent;
use Rplus::Util::Task qw(add_task);

use Rplus::Model::History::Manager;

use Data::Dumper;

no warnings 'experimental';

my $media_name = 'bn';
my $media_data;
my $parser = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %H:%M:%S');
my $ua;

sub enqueue_tasks {
    my ($location, $category) = @_;

    say 'loading ' . $media_name . ' - ' . $location . ' - ' . $category;

    my $list = _get_category($location,  $category);

    foreach (@{$list}) {

        my $eid = $_->{id} . '_0';

        unless (Rplus::Model::History::Manager->get_objects_count(query => [media => $media_name, location => $location, eid => $eid])) {
            say 'added' . $_->{url};
            Rplus::Model::History->new(media => $media_name, location => $location, eid => $eid)->save;
            add_task(
                'load_item',
                {media => $media_name, location => $location, url => $_->{url}},
                $media_name
            );
            #Rplus::Model::Task->new(url => $_->{url}, media => $media_name, location => $location)->save;
        }
    }
    say 'done';
}

sub _get_category {
    my ($location, $category) = @_;

    $media_data = Rplus::Class::Media->instance()->get_media($media_name, $location);
    $ua = Rplus::Class::UserAgent->new(Rplus::Class::Interface->instance()->get_interface());

    my @url_list;

    my $t = _get_url_list($media_data->{site_url} . $category, $media_data->{page_count}, $media_data->{pause});
    push @url_list, @{$t};

    return \@url_list;
}

sub _get_url_list {
    my ($category_page, $page_count, $pause) = @_;
    my @url_list;

    for(my $i = 1; $i <= $page_count; $i ++) {

        my $page_url = $category_page . '?start=' . 50 * ($i - 1);

        my $res = $ua->get_res($page_url, []);
        if ($res && $res->dom) {
            my $dom = $res->dom;

            $dom->find('div[class~="result"] tr')->each (sub {

                return unless $_->at('a');

                my $item_url = $_->at('a')->attr('href');

                my $item_id;
                if ($item_url =~ /(\d+)/) {
                    $item_id = $1;
                }

                push @url_list, {id => $item_id, url => $item_url, ts => ''};

            });
        }

        sleep $pause;
    }
    return \@url_list;
}

1;
