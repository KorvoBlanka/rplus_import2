package Rplus::Import::Item::Avito;

use DateTime::Format::Strptime;
use Mojo::Util qw(trim);

use Rplus::Model::Result;

use Rplus::Modern;
use Rplus::Class::Media;
use Rplus::Class::Interface;
use Rplus::Class::UserAgent;

use JSON;
use Data::Dumper;

no warnings 'experimental';


my $media_name = 'avito';
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
        source_url => $media_data->{site_url} . $item_url,
        type_code => 'other',
        offer_type_code => 'sale',
        add_date => ''
    };

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

    my $item_id = $dom->at('span[id="item_id"]')->text;

    # дата
    my $date_str = trim($dom->at('div[class="item-subtitle"]')->text);
    if ($date_str =~ /размещено (.+)\. объявление/i) {
        say $1;
        my $dt = _parse_date($1);
        $data->{add_date} = $dt->format_cldr("yyyy-MM-dd'T'HH:mm:ssZ");
    }

    # тип недвижимости и тип предложения
    my $params = lc($dom->find('div[class~="item-params"]')->first->all_text);
    if ($params =~ /сдам/) {
        $data->{offer_type_code} = 'rent';
        if ($params =~ /посуточно/) {
            $data->{rent_type} = 'short';
        }
    } else {
        $data->{offer_type_code} = 'sale';
    }

    if ($params =~ /квартир/) {
        $data->{type_code} = 'apartment';
    } elsif ($params =~ /таунхаус/) {
        $data->{type_code} = 'townhouse';
    } elsif ($params =~ /малосем/) {
        $data->{type_code} = 'apartment_small';
    } elsif ($params =~ /комнат/) {
        $data->{type_code} = 'room';
    } elsif ($params =~ /дом/) {
        $data->{type_code} = 'house';
    } elsif ($params =~ /дач/) {
        $data->{type_code} = 'dacha';
    } elsif ($params =~ /коттедж/) {
        $data->{type_code} = 'cottage';
    } elsif ($params =~ /участок/) {
        $data->{type_code} = 'land';
    } elsif ($params =~ /гараж/) {
        $data->{type_code} = 'garage';
    } elsif ($params =~ /торговое помещение/) {
        $data->{type_code} = 'market_place';
    } elsif ($params =~ /магазин/) {
        $data->{type_code} = 'market_place';
    } elsif ($params =~ /павильон/) {
        $data->{type_code} = 'market_place';
    } elsif ($params =~ /офис/) {
        $data->{type_code} = 'office_place';
    } elsif ($params =~ /нежилое помещение/) {
        $data->{type_code} = 'gpurpose_place';
    } elsif ($params =~ /склад/) {
        $data->{type_code} = 'warehouse_place';
    } elsif ($params =~ /производственное помещение/) {
        $data->{type_code} = 'production_place';
    } elsif ($params =~ /помещение свободного назначения/) {
        $data->{type_code} = 'gpurpose_place';
    } elsif ($params =~ /помещение/) {
        $data->{type_code} = 'gpurpose_place';
    }

    # описание
    my $dsk = $dom->find('div[itemprop="description"]')->first->all_text;
    $data->{'source_media_text'} = $dsk;

    # заголовок осн. информация
    my $main_title = $dom->find('h1[itemprop="name"]')->first->text;
    $main_title = trim $main_title;
    given($data->{'type_code'}) {
        when ('room') {
            my @bp = map {trim $_} grep { $_ && length($_) > 1 } split /[,()]/, $main_title;
            # комната м2 бла...
            if ($bp[0] =~ /^.*?(\d{1,}).*?$/) {
                $data->{'square_total'} = $1;
            }
            # d/d эт.
            if (defined $bp[1] && $bp[1] =~ /^(\d{1,2})\/(\d{1,2}).*?$/) {
                if ($2 >= $1) {
                    $data->{'floor'} = $1;
                    $data->{'floors_count'} = $2;
                }
            }
        }
        when ('apartment') {
            my @bp = map {trim $_} grep { $_ && length($_) > 1 } split /[,()]/, $main_title;
            # d-к квратира.
            if ($bp[0] =~ /^(\d{1,}).*?$/) {
                $data->{'rooms_count'} = $1;
            }
            # d м2.
            if ($bp[1] =~ /^(\d{1,}).*?$/) {
                $data->{'square_total'} = $1;
            }
            # d/d эт.
            if ($bp[2] =~ /^(\d{1,2})\/(\d{1,2}).*?$/) {
                if ($2 >= $1) {
                    $data->{'floor'} = $1;
                    $data->{'floors_count'} = $2;
                }
            }
        }
        when ('house') {
            given($main_title) {
                when (/дом/i) {
                }
                when (/коттедж/i) {
                    $data->{'type_code'} = 'cottage';
                }
                when (/дача/i) {
                    $data->{'type_code'} = 'land';
                }
                # wtf
                default {
                    say 'unknown realty type!';
                    next;
                }
            }

            # d м2 d сот || d м2
            if ($main_title !~ /участке/) {
                if ($main_title =~ /^.*?(\d{1,}).*?$/) {
                    $data->{'square_total'} = $1;
                }
            } elsif ($main_title =~ /^.*?(\d{1,}).*?(\d{1,}).*?$/) {
                $data->{'square_total'} = $1;
                $data->{'square_land'} = $2;
                $data->{'square_land_type'} = 'ar';
            }
        }
        when ('land') {
            if ($main_title =~ /(\d+(?:,\d+)?)\s+кв\.\s*м/) {
                $main_title =~ s/\s//;
                if ($main_title =~ /^(\d{1,}).*?$/) {
                    $data->{'square_land'} = $1;
                }
            } elsif ($main_title =~ s/(\d+)\s+сот\.?//) {
                $data->{'square_land'} = $1;
                $data->{'square_land_type'} = 'ar';
            } elsif ($main_title =~ s/(\d(?:,\d+)?)\s+га//) {
                $data->{'square_land'} = $1 =~ s/,/./r;
                $data->{'square_land_type'} = 'hectare';
            }
        }
        default {}
    }

    # Разделим остальную часть обявления на части и попытаемся вычленить полезную информацию
    my @bp = map {trim $_} grep { $_ && length($_) > 1 } split /[,()]/, $data->{'source_media_text'};
    for my $el (@bp) {
        # Этаж/этажность
        if ($el =~ /^(\d{1,2})\/(\d{1,2})$/) {
            if ($2 > $1) {
                $data->{'floor'} = $1;
                $data->{'floors_count'} = $2;
            }
            next;
        }

        for my $k (keys %{$META->{'params'}->{'dict'}}) {
            my %dict = %{$META->{'params'}->{'dict'}->{$k}};
            my $field = delete $dict{'__field__'};
            for my $re (keys %dict) {
                if ($el =~ /$re/i) {
                    $data->{$field} = $dict{$re};
                    last;
                }
            }
        }
    }

    # цена в рублях, переведем в тыс.
    my $price = $dom->find('span[itemprop="price"]')->first->all_text;
    $price =~s/\s//g;
    if ($price =~ /^(\d{1,}).*?$/) {
        $data->{'owner_price'} = $1 / 1000;
    }

    # адрес
    # нас пункт
    if ($dom->find('meta[itemprop="addressLocality"]')->first) {
        $data->{locality} = $dom->find('meta[itemprop="addressLocality"]')->first->attr('content');
    }

    # адр
    if ($dom->find('span[itemprop="streetAddress"]')->first) {
        $data->{address} = $dom->find('span[itemprop="streetAddress"]')->first->all_text;
    }

    my @owner_phones;
    my $item_phone = '';
    my $pkey = '';
    $dom->find('script')->each(sub{
        if ($_->all_text =~ /item.phone = '(.+)'/) {
            $item_phone = $1;
        }
    });

    $pkey = _phone_demixer($item_id * 1, $item_phone);

    sleep $media_data->{pause_item};

    my $m_url = 'https://m.avito.ru' . $item_url;

    $ua->get_res($m_url, [
        Host => 'm.avito.ru',
        Referer => $media_data->{site_url},
    ]);

    my $mr = $ua->get_res($m_url . '/phone/' . $pkey . '?async', [
        Host => 'm.avito.ru',
        Referer => $m_url,
        Accept => 'application/json, text/javascript, */*; q=0.01'
    ]);

    if ($mr && $mr->json) {
         my $phone_str = $mr->json->{phone};
        for my $x (split /[.,;:]/, $phone_str) {
            push @owner_phones, $x;
        }
    }
    $data->{'owner_phones'} = \@owner_phones;

    if ($dom->find('div[class="description_seller"]')->first->text =~ /Агентство/i ) {   # агенство?
        my $seller = $dom->find('div[id="seller"] strong[itemprop="name"]')->first->all_text;
        if ($seller !~ /Частное лицо/) {
            $data->{mediator_company} = $seller;
        }
    }

    # вытащим фото
    my @photos;
    $dom->find('meta[property="og:image"]')->each (sub {
        unless ($_->{content} =~ /logo/) {
            my $img_url = $_->{content};
            push @photos, $img_url;
        }
    });
    $data->{photo_url} = \@photos;

    return $data;
}

sub _phone_demixer {
    my ($id, $key) = @_;

    my @parts = $key =~ /[0-9a-f]+/g;

    my $mixed = join '', $id % 2 == 0 ? reverse @parts : @parts;
    my $s = length $mixed;
    my $r = '';
    my $k;

    for($k = 0; $k < $s; ++ $k) {
        if( $k % 3 == 0 ) {
            $r .= substr $mixed, $k, 1;
        }
    }

    return $r;
}

sub _parse_date {
    my $date = lc(shift);

    my $res;
    my $dt_now = DateTime->now();
    my $year = $dt_now->year();
    my $mon = $dt_now->month();
    my $mday = $dt_now->mday();

    if ($date =~ /сегодня в (\d{1,2}):(\d{1,2})/) {
        $res = $parser->parse_datetime("$year-$mon-$mday $1:$2");
        if ($res > $dt_now) {
            # substr 1 day
            #$res->subtract(days => 1);
        }
    } elsif ($date =~ /вчера в (\d{1,2}):(\d{1,2})/) {
        $res = $parser->parse_datetime("$year-$mon-$mday $1:$2");
        # substr 1 day
        $res->subtract(days => 1);
    } elsif ($date =~ /(\d+) (\w+) в (\d{1,2}):(\d{1,2})/) {
        my $a_mon = _month_num($2);
        my $a_year = $year;
        if ($a_mon > $mon) { $a_year -= 1; }
        $res = $parser->parse_datetime("$a_year-$a_mon-$1 $3:$4");
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
