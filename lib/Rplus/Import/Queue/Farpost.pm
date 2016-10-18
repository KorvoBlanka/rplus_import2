package Rplus::Import::Queue::Farpost;

use DateTime::Format::Strptime;
use Mojo::Util qw(trim);

use Rplus::Modern;
use Rplus::Class::Media;
use Rplus::Class::Interface;
use Rplus::Class::UserAgent;

use Rplus::Model::Task::Manager;
use Rplus::Model::History::Manager;

use Data::Dumper;

no warnings 'experimental';

my $media_name = 'farpost';
my $media_data;
my $parser = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %H:%M');
my $ua;

sub enqueue_tasks {
    my ($location, $category) = @_;

    say 'loading - ' . $media_name . ' - ' . $location . ' - ' . $category;

    my $list = _get_category($location,  $category);

    foreach (@{$list}) {

        my $eid = _make_eid($_->{id}, $_->{ts});

        say $_->{url};

        unless (Rplus::Model::History::Manager->get_objects_count(query => [media => $media_name, eid => $eid])) {
            Rplus::Model::History->new(media => $media_name, location => $location, eid => $eid)->save;
            Rplus::Model::Task->new(url => $_->{url}, media => $media_name, location => $location)->save;
        }
    }
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

        my $page_url = $i == 1 ? $category_page : $category_page . "?page=$i";

        my $res = $ua->get_res($page_url, [Host => $media_data->{host}]);
        next unless $res;
        my $dom = $res->dom;

        $dom->find('table[class~="viewdirBulletinTable"] > tbody > tr')->each (sub {
            my $a = $_->find('a[class~="bulletinLink"]')->first;
            return unless $a;

            my $item_id = $a->{name};
            my $item_url = $a->{href};

            my $date_str = trim($_->at('td[class="dateCell"]')->text);
            my $ts = _parse_date($date_str);

            push(@url_list, {id => $item_id, url => $item_url, ts => $ts});

        });

        unless ($i + 1 == $page_count) {
            sleep $pause;
        }
    }

    return \@url_list;
}

sub _parse_date {
    my $date = lc(shift);

    my $res;
    my $dt_now = DateTime->now(time_zone => $media_data->{timezone});
    my $year = $dt_now->year();
    my $mon = $dt_now->month();
    my $mday = $dt_now->mday();


    if ($date =~ /(\d{1,2}):(\d{1,2}), сегодня/) {
        $res = $parser->parse_datetime("$year-$mon-$mday $1:$2");
        if ($res > $dt_now) {
            # substr 1 day
            #$res->subtract(days => 1);
        }
    } elsif ($date =~ /(\d{1,2}):(\d{1,2}), вчера/) {
        $res = $parser->parse_datetime("$year-$mon-$mday $1:$2");
        $res->subtract(days => 1);
        if ($res > $dt_now) {
            # substr 1 day
            #$res->subtract(days => 1);
        }
    } elsif ($date =~ /(\d{1,2}):(\d{1,2}), (\d+) (\w+)/) {
        my $a_mon = _month_num($4);
        $res = $parser->parse_datetime("$year-$a_mon-$3 $1:$2");
    } else {
        $res = $dt_now;
    }

    $res->set_time_zone($media_data->{timezone});

    return $res;
}

sub _month_num {
    my $month_str = lc(shift);

    given ($month_str) {
        when (/янв/) {
            return 1;
        }
        when (/фев/) {
            return 2;
        }
        when (/мар/) {
            return 3;
        }
        when (/апр/) {
            return 4;
        }
        when (/мая/) {
            return 5;
        }
        when (/июн/) {
            return 6;
        }
        when (/июл/) {
            return 7;
        }
        when (/авг/) {
            return 8;
        }
        when (/сен/) {
            return 9;
        }
        when (/окт/) {
            return 10;
        }
        when (/ноя/) {
            return 11;
        }
        when (/дек/) {
            return 12;
        }
    }
    return 0;
}

sub _make_eid {
    my ($id, $date) = @_;
    return $id . '_' . $date->strftime('%Y%m%d')
}

1;
