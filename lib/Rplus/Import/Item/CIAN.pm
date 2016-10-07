package Rplus::Import::Item::CIAN;

use DateTime::Format::Strptime;
use Mojo::Util qw(trim);

use Rplus::Model::Result;

use Rplus::Modern;
use Rplus::Class::Media;
use Rplus::Class::Interface;
use Rplus::Class::UserAgent;
use Rplus::Util::PhoneNum qw(refine_phonenum);

use JSON;
use Data::Dumper;

no warnings 'experimental';


my $media_name = 'cian';
my $media_data;
my $parser = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %H:%M');
my $ua;

my $META = {
    params => {
        dict => {
            bathrooms => {
                '__field__' => 'bathroom_id',
                '^с\\/у\\s+смежн\\.?$' => 8,
                '^смежн\\.?\\s+с\\/у$' => 8,
                '^с\\/у\\s+разд\\.?$' => 3,
                '^без\\s+удобств$' => 1,
                '^с\\/у\\s+совм\\.?$' => 8
            },
            balconies => {
                '__field__' => 'balcony_id',
                '^б\\/з$' => 5,
                '^б\\/балк\\.?$' => 1,
                '^2\\s+лодж\\.?$' => 8,
                '^б\\/б$' => 1,
                '^балк\\.?$' => 2,
                '^лодж\\.?$' => 3,
                '^2\\s+балк\\.?$' => 7,
                '^л\\/з$' => 6
            },
            ap_schemes => {
                '__field__' => 'ap_scheme_id',
                '^улучшенная\\.?$' => 3,
                '^хрущевка\\.?$' => 2,
                '^хрущовка\\.?$' => 2,
                '^общежитие' => 6,
                '^индивидуальная\\.?$' => 6,
                '^индивидуальная\\.?\\s+планировка\\.?$' => 5,
                '^улучшенная\\.?$' => 3,
                '^брежневка\\.?$' => 3,
                '^новая\\.?\\s+планировка\\.?$' => 4,
                '^сталинка\\.?$' => 1,
                '^(?:улучшенная\\.?\\s+планировка\\.?)|(?:планировка\\.?\\s+улучшенная\\.?)|(?:улучшенная\\.)$' => 3,
                '^хрущ\\.?$' => 2,
                '^общежити' => 6,
                '^инд\\.?\\s+план\\.?$' => 5,
                '^брежн\\.?$' => 3,
                '^нов\\.?\\s+план\\.?$' => 4,
                '^стал\\.?$' => 1,
                '^(?:улучш\\.?\\s+план\\.?)|(?:план\\.?\\s+улучш\\.?)|(?:улучш\\.)$' => 3
            },
            house_types => {
                '__field__' => 'house_type_id',
                '^кирп\\.?$' => 1,
                '^монолит.+?\\-кирп\\.?$' => 7,
                '^монолитн?\\.?$' => 2,
                '^пан\\.?$' => 3,
                '^брус$' => 5,
                '^дерев\\.?$' => 4
            },
            conditions => {
                '__field__' => 'condition_id',
                '^соц\\.?\\s+ремонт$' => 2,
                '^тр\\.?\\s+ремонт$' => 6,
                'еврорем' => 4,
                '^отл\\.?\\s+сост\\.?$' => 12,
                '^хор\\.?\\s+сост\\.?$' => 11,
                '^сост\\.?\\s+хор\\.?$' => 11,
                '^удовл\\.?\\s+сост\\.?$' => 9,
                '^после\\s+строит\\.?$' => 1,
                '^сост\\.?\\s+отл\\.?$' => 12,
                '^дизайнерский ремонт$' => 5,
                '^п\\/строит\\.?$' => 1,
                '^сост\\.?\\s+удовл\\.?$' => 9,
                '^т\\.\\s*к\\.\\s*р\\.$' => 7,
                '^сделан ремонт$' => 3,
                '^норм\\.?\\s+сост\\.?$' => 10,
                '^треб\\.?\\s+ремонт$' => 6,
                '^сост\\.?\\s+норм\\.?$' => 10
            },
            room_schemes => {
                '__field__' => 'room_scheme_id',
                '^комн\\.?\\s+разд\\.?$' => 3,
                'икарус' => 5,
                '^разд\\.?\\s+комн\\.?$' => 3,
                '^смежн\\.?\\s+комн\\.?$' => 4,
                '^комн\\.?\\s+смежн\\.?$' => 4,
                '^кухня\\-гостиная$' => 2,
                '^студия$' => 1
            }
        },
    }
};

sub get_item {
    my ($location, $item_url) = @_;

    say 'loading ' . $media_name . ' - ' . $location . ' - ' . $item_url;
    my $data = _get_item($location, $item_url);
    say Dumper $data;

    my $realty = Rplus::Model::Result->new(metadata => to_json($data), media => $media_name, location => $location)->save;
    say 'saved ' . $realty->id;
}

sub _get_item {
    my ($location, $item_url) = @_;

    $media_data = Rplus::Class::Media->instance()->get_media($media_name, $location);;
    $ua = Rplus::Class::UserAgent->new(Rplus::Class::Interface->instance()->get_interface());

    my $data = {
        source_media => $media_name,
        source_url => $item_url,
        type_code => 'other',
        offer_type_code => 'sale',
        add_date => ''
    };

    sleep $media_data->{pause};
    parse_adv($data, $item_url);

    return $data;
}

sub parse_adv {
    my ($data, $item_url) = @_;

    my $source_url = $media_data->{site_url} . $item_url;

    my $res = $ua->get_res($source_url, [
        Host => $media_data->{host},
        Referer => $media_data->{site_url}
    ]);
    my $dom = $res->dom;

    my $offers;
    $dom->find('script')->each (sub {
        if ($_->all_text =~ 'window._offers = ({.+});') {
            $offers =  from_json($1);
        }
    });

    my $obj = (values %$offers)[0];

    my $date_str = $obj->{added}->{strict};
    my $dt = _parse_date($date_str);

    $data->{add_date} = $dt->datetime();
    $data->{owner_phones} = [refine_phonenum($obj->{phone})];
    $data->{price} = $obj->{price}->{rur} / 1000;

    if ($data->{deal_type} eq 'sale') {
        $data->{offer_type_code} = 'sale';
    } else {
        $data->{offer_type_code} = 'rent';
    }

    my $t = trim($dom->at('div[class~="object_descr_title"]')->text);

    if ($t =~ /посуточно/) {
        $data->{rent_type} = 'short';
    } else {
        $data->{rent_type} = 'long';
    }
    # rooms count and type_code
    given($t) {
        when (/(\d+)-комн. кв/i) {
            $data->{type_code} = 'apartment';
            $data->{rooms_count} = $1;
        }

        when (/студия/i) {
            $data->{type_code} = 'apartment';
        }

        when (/свободная планировка/i) {
            $data->{type_code} = 'apartment';
        }

        when (/таунхаус/i) {
            $data->{type_code} = 'townhouse';
        }

        when (/комната/i) {
            $data->{type_code} = 'room';
        }

        when (/дом/i) {
            $data->{type_code} = 'house';
        }

        when (/участок/i) {
            $data->{type_code} = 'land';
        }

        when (/гараж/i) {
            $data->{type_code} = 'garage';
        }

        when (/склад/i) {
            $data->{type_code} = 'warehouse_place';
        }

        when (/торговая площадь/i) {
            $data->{type_code} = 'market_place';
        }

        when (/помещение под производство/i) {
            $data->{type_code} = 'production_place';
        }

        when (/здание/i) {
            $data->{type_code} = 'building';
        }

        when (/своб. назнач./i) {
            $data->{type_code} = 'gpurpose_place';
        }

        when (/офис/i) {
            $data->{type_code} = 'office_place';
        }
    }

    $t = $dom->at('h1[class~="object_descr_addr"]');
    if ($t) {
        my $t = trim($t->all_text);
        my @ap = split /,/, $t;
        @ap = map {trim $_} @ap;
        $data->{'locality'} = $ap[0];
        splice(@ap, 0, 1);

        $data->{address} = join(', ', @ap);
    }

    $t = $dom->at('div[class~="object_descr_text"]');
    if ($t) {
        $data->{source_media_text} = trim($t->text);
    }

    $t = $dom->at('table[class~="object_descr_props"]');

    $t->find('tr')->each(sub {
        my $h = $_->at('th')->text;
        return unless $_->at('td');
        my $d = $_->at('td')->text;

        given($h) {
            when (/этаж/i) {
                if ($d =~ /(\d+) \/ (\d+)/) {
                    $data->{floor} = $1;
                    $data->{floors_count} = $2;
                }
            }
            when (/площадь дома/i) {
                if ($d =~ /(\d{1,}).*?/) {
                    $data->{square_total} = $1;
                }
            }
            when (/площадь участка/i) {
                if ($d =~ /(\d{1,}).*?/) {
                    $data->{square_land} = $1;
                    $data->{square_land_type} = 'ar';
                }
            }
            when (/общая площадь/i) {
                if ($d =~ /(\d{1,}).*?/) {
                    $data->{square_total} = $1;
                }
            }
            when (/площадь комнат/i) {
                if ($d =~ /(\d{1,}).*?/) {
                    $data->{square_total} = $1;
                }
            }
            when (/жилая площадь/i) {
                if ($d =~ /(\d{1,}).*?/) {
                    $data->{square_living} = $1;
                }
            }
            when (/площадь кухни/i) {
                if ($d =~ /(\d{1,}).*?/) {
                    $data->{square_kitchen} = $1;
                }
            }
            when (/площадь/i) {
                if ($d =~ /(\d{1,}).*?/) {
                    $data->{square_total} = $1;
                }
            }
            when (/количество этажей/i) {
                if ($d =~ /(\d+)/) {
                    $data->{floors_count} = $1;
                }
            }
            when (/санузел/i) {

            }
            when (/балкон/i) {

            }
            when (/ванная комната/i) {

            }
            when (/ремонт/i) {

            }
        }
    });

    my $sn = $dom->at('h3[class="realtor-card__title"] a');
    if ($sn) {
        foreach (@{$data->{'owner_phones'}}) {
            $data->{mediator_company} = $sn->all_text;
        }
    }

    my @photo_url;
    for my $photo (@{$obj->{photos}}) {
        my $img_url = $photo->{img};
        $img_url =~ s/-2.jpg/-1.jpg/;
        push @photo_url, $img_url;
    }
    $data->{photo_url} = \@photo_url;

    return $data;
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

1;
