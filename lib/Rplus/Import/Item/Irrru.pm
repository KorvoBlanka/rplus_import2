package Rplus::Import::Item::Irrru;

use DateTime::Format::Strptime;
use MIME::Base64;
use Mojo::Util qw(trim);

use Rplus::Model::Result;

use Rplus::Modern;
use Rplus::Class::Media;
use Rplus::Class::Interface;
use Rplus::Class::UserAgent;

use JSON;
use Data::Dumper;

no warnings 'experimental';


my $media_name = 'irr';
my $media_data;
my $parser = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %H:%M');
my $ua;


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

    my $source_url = $item_url;
    $data->{source_url} = $source_url;

    say $source_url;

    my $res = $ua->get_res($source_url, [
        Host => $media_data->{host},
        Referer => $media_data->{site_url}
    ]);
    my $dom = $res->dom;

    # дата размещения
    my $date_str = trim($dom->find('div[class~="updateProduct"]')->first->text);
    my $dt = _parse_date($date_str);
    $data->{add_date} = $dt->format_cldr("yyyy-MM-dd'T'HH:mm:ssZ");

    # тип недвижимости и тип предложения
    my $breadcrumbs = lc($dom->find('nav[class~="breadcrumbs"]')->first->all_text);
    if ($breadcrumbs =~ /аренда/i) {
        $data->{offer_type_code} = 'rent';
        if ($breadcrumbs =~ /на сутки/i) {
            $data->{rent_type} = 'short';
        }
    } else {
        $data->{offer_type_code} = 'sale';
    }

    if ($breadcrumbs =~ /квартир/) {
        $data->{type_code} = 'apartment';
    } elsif ($breadcrumbs =~ /таунхаус/) {
        $data->{type_code} = 'townhouse';
    } elsif ($breadcrumbs =~ /малосем/) {
        $data->{type_code} = 'apartment_small';
    } elsif ($breadcrumbs =~ /комнат/) {
        $data->{type_code} = 'room';
    } elsif ($breadcrumbs =~ /домов/) {
        $data->{type_code} = 'house';
    } elsif ($breadcrumbs =~ /дач/) {
        $data->{type_code} = 'dacha';
    } elsif ($breadcrumbs =~ /коттедж/) {
        $data->{type_code} = 'cottage';
    } elsif ($breadcrumbs =~ /участок/) {
        $data->{type_code} = 'land';
    } elsif ($breadcrumbs =~ /гараж/) {
        $data->{type_code} = 'garage';
    } elsif ($breadcrumbs =~ /торговля и сервис/) {
        $data->{type_code} = 'market_place';
    } elsif ($breadcrumbs =~ /магазин/) {
        $data->{type_code} = 'market_place';
    } elsif ($breadcrumbs =~ /павильон/) {
        $data->{type_code} = 'market_place';
    } elsif ($breadcrumbs =~ /офис/) {
        $data->{type_code} = 'office_place';
    } elsif ($breadcrumbs =~ /нежилое помещение/) {
        $data->{type_code} = 'gpurpose_place';
    } elsif ($breadcrumbs =~ /склад/) {
        $data->{type_code} = 'warehouse_place';
    } elsif ($breadcrumbs =~ /производство/) {
        $data->{type_code} = 'production_place';
    } elsif ($breadcrumbs =~ /свободного назначения/) {
        $data->{type_code} = 'gpurpose_place';
    } elsif ($breadcrumbs =~ /помещение/) {
        $data->{type_code} = 'gpurpose_place';
    } else {
        $data->{type_code} = 'other';
    }

    my @owner_phones = ();
    if ($dom->find('div[class~="js-productPagePhoneLabel"]')->first) {
        my $phone_num_raw = decode_base64($dom->find('div[class~="js-productPagePhoneLabel"]')->first->attr('data-phone'));
        push @owner_phones, $phone_num_raw;
    } else {
        say 'no phone?'
    }

    $data->{'owner_phones'} = \@owner_phones;

    my $n = $dom->find('div[class~="productPage__price"]')->first;
    if ($n) {
        my $cost = trim($n->all_text);
        if ($cost) {
            $cost =~ s/\D//g;
            $data->{'owner_price'} = $cost / 1000;
        }
    }

    my $text;
    $n = $dom->find('p[class~="js-productPageDescription"]')->first;
    if ($n) {
        $text = $n->all_text;
        $data->{'source_media_text'} = trim($text);
    }

    my $addr;
    $n = $dom->find('div[class~="productPage__infoTextBold js-scrollToMap"]')->first;
    if ($n) {
        $addr = $n->all_text;
    }

    if ($addr) {

        my $t = trim($addr);
        my @ap = split /,/, $t;
        $data->{'locality'} = $ap[0];
        splice(@ap, 0, 1);
        $data->{'address'} = join(', ', @ap);

    }

    $dom->find('div[class="productPage__characteristicsItem"]')->each(sub {

        #my $tfield = lc $_->text;
        my $tkey = trim($_->at('span[class~="productPage__characteristicsItemTitle"]')->all_text);
        my $tval = trim($_->at('span[class~="productPage__characteristicsItemValue"]')->all_text);

        $tval =~ s/[\h\v]+/ /g;

        say $tkey . ' <-> ' . $tval;

        given ($tkey) {
            when ("этаж") {
                if($tval =~ /(\d+) из (\d+)/) {
                    $data->{'floor'} = $1;
                    $data->{'floors_count'} = $2;
                } else {
                    $data->{'floor'} = $tval;
                }

            }
            when ("комнаты") {
                $data->{'rooms_count'} = $tval;
            }
            when ("общая площадь") {
                my $tnum;
                if($tval =~ /(\d+(?:,\d+)?)/) {
                    $tnum = $1;
                } else {
                    $tnum =~ s/\D//g;
                }
                $data->{'square_total'} = $tnum;
            }
            when ("жилая площадь") {
                my $tnum;
                if($tval =~ /(\d+(?:,\d+)?)/) {
                    $tnum = $1;
                } else {
                    $tnum =~ s/\D//g;
                }
                $data->{'square_living'} = $tnum;
            }
        }
    });

    $dom->find('li[class~="productPage__infoColumnBlockText"]')->each(sub {

        my $tfield = lc $_->text;
        my $tkey = '';
        my $tval = '';

        if ($tfield =~ /(.+?): (.+)/) {
          $tkey = $1;
          $tval = $2;
        } else {
          $tkey = $tfield;
          $tval = $tfield;
        }

        my $tnum = $tval;

        if($tnum =~ /(\d+(?:,\d+)?)/) {
            $tnum = $1;
        } else {
            $tnum =~ s/\D//g;
        }

        say '---';
        say 'key: ' . $tkey;
        say 'kval: ' . $tval;

        given ($tkey) {

            when ("этаж") {
                $data->{'floor'} = $tnum;
            }

            when ("количество этажей") {
                $data->{'floors_count'} = $tnum;
            }

            when ("этажей в здании") {
                $data->{'floors_count'} = $tnum;
            }

            when ("количество комнат") {
                $data->{'rooms_count'} = $tnum;
            }

            when ("комнат в квартире") {
                $data->{'rooms_count'} = $tnum;
            }

            when ("общая площадь") {
                $data->{'square_total'} = $tnum;
            }

            when ("жилая площадь") {
                $data->{'square_living'} = $tnum;
            }

            when ("площадь кухни") {
                $data->{'square_kitchen'} = $tnum;
            }

            when ("материал стен") {
                given($tval) {
                    when (/кирпичный/) {
                        $data->{'house_type_id'} = 1;
                    }
                    when (/деревянный/) {
                        $data->{'house_type_id'} = 4;
                    }
                    when (/панельный/) {
                        $data->{'house_type_id'} = 3;
                    }
                    when (/монолитный/) {
                        $data->{'house_type_id'} = 2;
                    }
                }
            }

            when ("ремонт") {

            }

            when ("балкон/лоджия") {

            }

            when ("санузел") {

            }

            when ("площадь строения") {
                $data->{'square_total'} = $tnum;
            }

            when ("площадь участка") {
                $data->{'square_land'} = $tnum;
                $data->{'square_land_type'} = 'ar';
            }

            when ("строение") {
                if ($tval =~ /коттедж/i) {
                    $data->{'type_code'} = 'cottage';
                } else {

                }
            }

            when ("комнат в квартире/общежитии") {
                $data->{'rooms_count'} = $tnum;
            }

            when ("количество комнат на продажу") {
                $data->{'rooms_offer_count'} = $tnum;
            }

            when ("комнат сдается") {
                $data->{'rooms_offer_count'} = $tnum;
            }

            when ("площадь арендуемой комнаты") {
                $data->{'square_total'} = $tnum;
            }

            when ("площадь продажи") {
                $data->{'square_total'} = $tnum;
            }

            when ("период аренды") {
                if ($tval =~ /краткосрочная/i) {
                    $data->{'rent_type'} = 'short';
                }
            }
        }
    });


    my @photos;
    $dom->find('div[class~="productGallery"] img')->each ( sub {
        my $img_url = $_->attr('data-src');
        push @photos, $img_url;
    });
    $data->{photo_url} = \@photos;

    if (my $user_node = $dom->find('div[class~="productPage__inlineWrapper"]')->first) {
        my $offer_count_str = $user_node->at('div[class~="productPage__infoText productPage__infoText_inline"]')->text;
        my $offer_count = $offer_count_str =~ s/\D//g;
        my $seller = trim($user_node->at('div[class~="productPage__infoTextBold productPage__infoTextBold_inline"]')->all_text);

        if ($offer_count > $media_data->{offer_count_limit}) {
            $data->{mediator_company} = $seller;
        }
    }

    # доп проверки
    if ($data->{'floor'} && $data->{'floors_count'}) {
        if ($data->{'floor'} * 1 > $data->{'floors_count'} * 1) {
            $data->{'floor'} = $data->{'floors_count'};
        }
    }
}

sub _parse_date {
    my $date = lc(shift);

    say $date;

    my $res;
    my $dt_now = DateTime->now();
    my $year = $dt_now->year();
    my $mon = $dt_now->month();
    my $mday = $dt_now->mday();

    if ($date =~ /сегодня, (\d{1,2}):(\d{1,2})/) {
        $res = $parser->parse_datetime("$year-$mon-$mday $1:$2");
        if ($res > $dt_now) {
            # substr 1 day
            #$res->subtract(days => 1);
        }
    } elsif ($date =~ /(\d+) (\w+)/) {
        my $a_mon = _month_num($2);
        $res = $parser->parse_datetime("$year-$a_mon-$1 12:00");
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
