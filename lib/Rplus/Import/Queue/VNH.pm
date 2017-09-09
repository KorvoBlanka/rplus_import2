package Rplus::Import::Queue::VNH;

use DateTime::Format::Strptime;

use Rplus::Modern;
use Rplus::Class::Media;
use Rplus::Class::Interface;
use Rplus::Class::UserAgent;
use Rplus::Util::Task qw(add_task);

use Rplus::Model::History::Manager;

use File::Basename;
use Data::Dumper;

no warnings 'experimental';

my $media_name = 'vnh';
my $media_data;
my $parser = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %H:%M:%S');
my $ua;

my @categories_list;

for(my $i = 1; $i <= 2; $i ++){
    for(my $j = 1; $j <= 6; $j ++){
        if($j == 6){
            for(my $k = 1; $k <= 8; $k ++){
                push @categories_list, ("offers_type=$i&estate=$j&purpose=$k");
            }
        } else{
            push @categories_list, ("offers_type=$i&estate=$j&purpose=");
        }
    }
}


sub enqueue_tasks {
    my ($location, $category) = @_;

    $media_data = Rplus::Class::Media->instance()->get_media($media_name, $location);
    $ua = Rplus::Class::UserAgent->new(Rplus::Class::Interface->instance()->get_interface());

    foreach (@categories_list) {
        my $category = '?city=' . $media_data->{city} . '&' . $_ . "&sort=" . $media_data->{sort} . "&limit=" . $media_data->{limit};
        say 'loading ' . $media_name . ' - ' . $location . ' - ' . $category;

        my $list = _get_category($location,  $category);

        foreach (@{$list}) {

            my $eid = _make_eid($_->{id}, $_->{ts});

            unless (Rplus::Model::History::Manager->get_objects_count(query => [media => $media_name, location => $location, eid => $eid])) {
                say 'added ' . $_->{url};
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
}

sub _get_category {
    my ($location, $category) = @_;

    my @url_list;

    my $t = _get_url_list($category, $media_data->{page_count}, $media_data->{pause});
    push @url_list, @{$t};

    return \@url_list;
}

sub _get_url_list {
    my ($category_page, $page_count, $pause) = @_;
    my @url_list;

    for(my $i = 1; $i <= $page_count; $i ++) {

        my $page_url = $media_data->{site_url} . '/filter/' . $i . $category_page;
        my $res = $ua->get_res($page_url, []);
        if ($res && $res->dom) {
            my $dom = $res->dom;

            $dom->find('div[class="teaser teaser_filter "]')->each (sub {

                my $item_id;
                my $item_url = $media_data->{site_url} . $_->at('div')->at('div')->at('a')->{href};

                if ($item_url =~ /\/(\d+)$/) {
                    $item_id = $1;
                }
                my $date_str = $_->find('div[class="meta_top"]')->first->text;
                my $dt = _parse_date($date_str);

                push @url_list, {id => $item_id, url => $item_url, ts => $dt};
            });
        }
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

    if ($date =~ /сегодня (\d{1,2}):(\d{1,2})/) {
        $res = $parser->parse_datetime("$year-$mon-$mday $1:$2:00");
        if ($res > $dt_now) {
            # substr 1 day
            $res->subtract(days => 1);
        }
    } elsif ($date =~ /вчера (\d{1,2}):(\d{1,2})/) {
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
