package Rplus::Import::Queue::CIAN;

use DateTime::Format::Strptime;

use Rplus::Modern;
use Rplus::Class::Media;
use Rplus::Class::Interface;
use Rplus::Class::UserAgent;

use Rplus::Model::Task::Manager;
use Rplus::Model::History::Manager;

use JSON;
use Data::Dumper;

no warnings 'experimental';

my $media_name = 'cian';
my $media_data;
my $parser = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %H:%M:%S');
my $ua;

sub enqueue_tasks {
    my ($location, $category) = @_;

    say 'loading ' . $media_name . ' - ' . $location . ' - ' . $category;

    my $list = _get_category($location,  $category);

    foreach (@{$list}) {

        my $eid = _make_eid($_->{id}, $_->{ts});

        unless (Rplus::Model::History::Manager->get_objects_count(query => [media => $media_name, eid => $eid])) {
            say $_->{url};
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

        my $res = $ua->get_res($category_page . '?p=' . $i, []);
        next unless $res;
        my $dom = $res->dom;


        my $offers;
        $dom->find('script')->each (sub {
          if ($_->all_text =~ 'window._offers = ({.+});') {
            $offers =  from_json($1);
          }
        });

        return [] unless $offers;

        my %objs = values %$offers;

        foreach my $key (keys %objs) {
            my $obj = $objs{$key};

            my $item_url = $obj->{link};
            my $item_id = $obj->{id};
            my $date_str = $obj->{added}->{strict};
            my $ts = _parse_date($date_str);

            push(@url_list, {id => $item_id, url => $item_url, ts => $ts});
        }

        #$dom->find('div[class~="catalog-list"] div[class~="item"]')->each (sub {

        #    my $do = $_->find('div[class="description"]')->first;

        #    my $item_url = $do->at('h3 a')->{href};
        #    my $item_id = substr $_->{id}, 1;
        #    my $date_str = $do->find('div[class~="date"]')->first->all_text;

        #    my $ts = _parse_date($date_str);

        #    push(@url_list, {id => $item_id, url => $item_url, ts => $ts});

        #});

        unless ($i + 1 == $page_count) {
            sleep $pause;
        }
    }

    return \@url_list;
}

sub _parse_date {
    my $date = lc(shift);

    my $res;
    my $dt_now = DateTime->now();
    my $year = $dt_now->year();
    my $mon = $dt_now->month();
    my $mday = $dt_now->mday();

    if ($date =~ /сегодня, (\d{1,2}):(\d{1,2})/) {
        $res = $parser->parse_datetime("$year-$mon-$mday $1:$2:00");
        if ($res > $dt_now) {
            # substr 1 day
            $res->subtract(days => 1);
        }
    } elsif ($date =~ /вчера, (\d{1,2}):(\d{1,2})/) {
        $res = $parser->parse_datetime("$year-$mon-$mday $1:$2:00");
        # substr 1 day
        $res->subtract(days => 1);
    } elsif ($date =~ /(\d+) (\w+) (\d{1,2}):(\d{1,2})/) {
        my $a_mon = _month_num($2);
        my $a_year = $year;
        if ($a_mon > $mon) { $a_year -= 1; }
        $res = $parser->parse_datetime("$a_year-$a_mon-$1 $3:$4:00");
    } else {
        $res = $dt_now;
    }

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
