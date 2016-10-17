package Rplus::Import::Item::Farpost;

use DateTime::Format::Strptime;
use Mojo::Util qw(trim);

use Rplus::Model::Result;

use Rplus::Modern;
use Rplus::Class::Media;
use Rplus::Class::Interface;
use Rplus::Class::UserAgent;

use JSON;
use Data::Dumper;

use utf8;

no warnings 'experimental';


my $media_name = 'farpost';
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
    say $data->{source_media_text};
    my $realty = Rplus::Model::Result->new(metadata => to_json($data), media => $media_name, location => $location)->save;
    say 'saved ' . $realty->id;
}

sub _get_item {
    my ($location, $item_url) = @_;

    $media_data = Rplus::Class::Media->instance()->get_media($media_name, $location);
    $ua = Rplus::Class::UserAgent->new(Rplus::Class::Interface->instance()->get_interface());

    my $data = {
        source_media => $media_name,
        source_url => '',
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
    $data->{source_url} = $source_url;

    my $res = $ua->get_res($source_url, [
        Host => $media_data->{host},
        Referer => $media_data->{site_url}
    ]);
    my $dom = $res->dom;

    # дата
    my $date_str = $dom->at('a[class="ajaxLink"]')->text;
    my $dt = _parse_date($date_str);
    $data->{add_date} = $dt->format_cldr("yyyy-MM-dd'T'HH:mm:ssZ");

    # описание
    $data->{'source_media_text'} = '';

    if (my $text = $dom->at('p[data-field="text"]')) {
        $data->{'source_media_text'} = trim($text->text);
    }

    if (my $features = $dom->at('p[data-field="realtyFeature"]')) {
        $data->{'source_media_text'} .= trim($features->text);
    }

    if (my $features = $dom->at('p[data-field="realtyFurnitureAndHousehold"]')) {
        $data->{'source_media_text'} .= "\n" . trim($features->text);
    }

    if (my $features = $dom->at('p[data-field="realtyInfrastructure"]')) {
        $data->{'source_media_text'} .= "\n" . trim($features->text);
    }

    # найдем телефон
    my @owner_phones = ();
    if ($dom->find('div[class="contacts"]')->size > 0) {

        sleep 5;

        my $contacts = $dom->find('div[class="contacts"]')->first;
        my $c_ref = $contacts->find('a[class~="viewAjaxContacts"]')->first->{href};

        my $retry = 5;
        while ($retry) {
            $retry -= 1;

            $ua->{ua}->cookie_jar->add(Mojo::Cookie::Response->new(
                name   => 'no_ga',
                value  => '1',
                domain => 'farpost.ru',
                path   => '/'
            ));

            my $c_res = $ua->get_res($media_data->{site_url} . $c_ref . '?ajax=1&paid=1', [
                Accept => '*/*',
                Host => $media_data->{host},
                Referer => $source_url
            ]);

            if ($c_res) {
                my $c_dom = $c_res->dom;
                if ($c_dom->find('form')->size > 0) {
                    say 'capcha, retry';
                    sleep 10;
                } else {

                    my $phone_str = $c_dom->find('span[class="phone"]')->each(sub {
                        my $phone_str = $_->text;
                        $phone_str =~ s/\D//g;
                        if (length $phone_str > 0) {
                            push @owner_phones, $phone_str;
                        }
                    });
                    $retry = 0;
                }
            }
        }
    }
    $data->{'owner_phones'} = \@owner_phones;

    $dom->find('div[class="fieldset"] > div[class="field"] > div[class="value"] > span')->each(sub {
        if (lc($_->text) =~ /агентства/) {
            my $seller = trim($dom->find('span[class~="userNick"]')->first->all_text);
            $data->{mediator_company} = $seller;
        }
    });

    my $addr;
    # адрес, улица + номер дома или только улица

    my $addr_o = $dom->find('span[data-field="street-district"]');
    if ($addr_o->size > 0) {
        $addr = trim($addr_o->first->text);
    } else {
        my $nb = $dom->find('span[data-field="street-buildingId"]');
        my $ns = $dom->find('span[data-field="street"]');
        if ($nb->size > 0) {
            $addr = trim($nb->first->all_text);
        } elsif ($ns->size > 0) {
            $addr = trim($ns->first->all_text);
        }
    }

    if ($addr) {
        $data->{'address'} = trim($addr);
    }

    $data->{'locality'} = $media_data->{locality};

    my $t = $data->{source_url};
    # offer type code
    if ($t =~ /rent/i) {
        $data->{offer_type_code} = 'rent';
    } else {
        $data->{offer_type_code} = 'sale';
    }

    # type code
    if ($t =~ /flats/i) {
        $data->{'type_code'} = 'apartment';
    }
    if ($t =~ /apartment/i) {
        $data->{'type_code'} = 'apartment';
    }
    if ($t =~ /houses/i) {
        $data->{'type_code'} = 'house';
    }
    if ($t =~ /land/i) {
        $data->{'type_code'} = 'land';
    }
    if ($t =~ /dacha/i) {
        $data->{'type_code'} = 'dacha';
    }
    if ($t =~ /garage/i) {
        $data->{'type_code'} = 'garage';
    }
    if ($t =~ /business_realty/i) {
        $data->{'type_code'} = 'other';
    }

    given($data->{'type_code'}) {
        when ('other') {
            my $n = $dom->find('span[data-field="subject"]');
            if ($n->size > 0) {
                my $t = trim($n->first->text);
                if ($t =~ /офис/i) {
                    $data->{'type_code'} = 'office_place';
                }
                elsif ($t =~ /торговое помещение/i) {
                    $data->{'type_code'} = 'market_place';
                }
                elsif ($t =~ /свободного назначения/i) {
                    $data->{'type_code'} = 'gpurpose_place';
                }
                elsif ($t =~ /производствен/i) {
                    $data->{'type_code'} = 'production_place';
                }
                elsif ($t =~ /магазин/i) {
                    $data->{'type_code'} = 'market_place';
                }
                elsif ($t =~ /павильон/i) {
                    $data->{'type_code'} = 'market_place';
                }
                elsif ($t =~ /склад/i) {
                    $data->{'type_code'} = 'warehouse_place';
                }
                elsif ($t =~ /баз[а|у]/i) {
                    $data->{'type_code'} = 'warehouse_place';
                }
                elsif ($t =~ /авто-комплекс/i) {
                    $data->{'type_code'} = 'autoservice_place';
                }
                elsif ($t =~ /нежилое/i) {
                    $data->{'type_code'} = 'gpurpose_place';
                }
                elsif ($t =~ /помещение/i) {
                    $data->{'type_code'} = 'gpurpose_place';
                }
                elsif ($t =~ /здание/i) {
                    $data->{'type_code'} = 'building';
                }
            }
        }
        when ('apartment') {
            # квартира или комната
            # количество комнат
            my $n = $dom->find('span[data-field="flatType"]');
            if ($n->size) {
                $t = trim($n->first->text);
                # d-к квратира.
                if ($t eq 'Комната') {
                    $data->{'category_code'} = 'room';
                    $data->{'type_code'} = 'room';
                } elsif ($t =~ /(\d{1,}).*?$/) {
                    $data->{'rooms_count'} = $1;
                }
            }

            # площадь
            $n = $dom->find('span[data-field="areaTotal"]');
            if ($n->size > 0) {
                $t = trim($n->first->text);
                # d м2.
                if ($t =~ /(\d{1,}).*?$/) {
                    $data->{'square_total'} = $1;
                }
            }
        }
        when ('house') {
            # дом или коттедж
            my $n = $dom->find('span[data-field="subject"]');
            if ($n->size > 0) {
                $t = trim($n->first->text);
                if ($t =~ /коттедж/i) {
                    $data->{'type_code'} = 'cottage';
                }
            }

            # жилая площадь
            $n = $dom->find('span[data-field="areaLiving"]');
            if ($n->size > 0) {
                $t = trim($n->first->text);
                # d м2.
                if ($t =~ /^(\d{1,}).*?$/) {
                    $data->{'square_total'} = $1;
                }
            }

            # площадь участка
            $n = $dom->find('span[data-field="areaTotal"]');
            if ($n->size > 0) {
                $t = trim($n->first->text);
                if ($t =~ /(\d+(?:,\d+)?)\s+кв\.\s*м/) {
                    $t =~ s/\s//;
                    if ($t =~ /^(\d{1,}).*?$/) {
                        $data->{'square_land'} = $1;
                    }
                } elsif ($t =~ s/(\d+)\s+сот\.?//) {
                    $data->{'square_land'} = $1;
                    $data->{'square_land_type'} = 'ar';
                } elsif ($t =~ s/(\d(?:,\d+)?)\s+га//) {
                    $data->{'square_land'} = $1 =~ s/,/./r;
                    $data->{'square_land_type'} = 'hectare';
                }
            }
        }
        when ('land') {
            # земельный участок
            # площадь участка
            my $n = $dom->find('span[data-field="areaTotal"]');
            if ($n->size > 0) {
                $t = trim($n->first->text);
                if ($t =~ /(\d+(?:,\d+)?)\s+кв\.\s*м/) {
                    $t =~ s/\s//;
                    if ($t =~ /^(\d{1,}).*?$/) {
                        $data->{'square_land'} = $1;
                    }
                } elsif ($t =~ s/(\d+)\s+сот\.?//) {
                    $data->{'square_land'} = $1;
                    $data->{'square_land_type'} = 'ar';
                } elsif ($t =~ s/(\d(?:,\d+)?)\s+га//) {
                    $data->{'square_land'} = $1 =~ s/,/./r;
                    $data->{'square_land_type'} = 'hectare';
                }
            }
        }
        default {}
    }

    my $n = $dom->find('span[data-field="wallMaterial"]');

    if ($n->size > 0) {
        $t = trim($n->first->text);

        given ($t) {
            when (/кирпичный/) {
                $data->{'house_type_id'} = 1;
            }
            when (/панельный/) {
                $data->{'house_type_id'} = 3;
            }
            when (/монолитный/) {
                $data->{'house_type_id'} = 2;
            }
            when (/деревянный/) {
                $data->{'house_type_id'} = 4;
            }
            when (/шлакобетон/) {
                $data->{'house_type_id'} = 8;
            }
        }
    }


    $n = $dom->find('span[data-field="floor-floorCount"]');

    if ($n->size > 0) {
        $t = trim($n->first->find('strong')->[1]->text);
        $data->{'floors_count'} = $t;
    }


    $n = $dom->find('span[data-field="rentPeriod"]');

    if ($n->size > 0) {
        $t = trim($n->first->text);
        if ($t =~ /долгосрочная/i) {
            $data->{'rent_type'} = 'long';
        } else {
            $data->{'rent_type'} = 'short';
        }
    }

    # цена в рублях, переведем в тыс.
    $n = $dom->find('span[data-field="price"]');
    unless ($n->size) {
        $n = $dom->find('span[data-field="price-agencySupportCommission"]');
    }
    if ($n->size > 0) {
        $t = trim($n->first->all_text);
        $t =~s/\s//g;
        if ($t =~ /^(\d{1,}).*?$/) {
            $data->{'owner_price'} = $1 / 1000;
        }
    }


    # Разделим остальную часть обявления на части и попытаемся вычленить полезную информацию
    my @bp = grep { $_ && length($_) > 1 } trim(split /[,()]/, $data->{source_media_text});
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
    # Этаж#2
    if (!$data->{'floor'} && $data->{source_media_text} =~ /(\d{1,2})\s+эт\.?/) {
        $data->{'floor'} = $1;
    }

	# вытащим фото
	$dom->find('div[class="bulletinImages"] img')->each ( sub {
		my $img_url = $_->{'data-zoom-image'};
		unless ($img_url) {
			$img_url = $_->{'src'};
		}
		push @{$data->{photo_url}}, $img_url;
	});
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


1;
