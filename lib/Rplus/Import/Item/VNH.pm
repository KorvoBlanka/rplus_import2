package Rplus::Import::Item::VNH;

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


my $media_name = 'vnh';
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

    my $title = $dom->at('div[class="item_full"]')->at('h1')->text;
    say $title;

    if ($title =~ /аренда/i) {
        $data->{rent_type} = 'rent';
    }

    $data->{type_code} = _get_type_code($title);


    if ($data->{offer_type_code} eq 'rent'){
        $data->{rent_type} = 'long';
    }

    my $adress=$dom->find('p[class="address"]')->first;
    if ($adress=~/<p class="address">(.+?), ([^\d].+)<br>(.+)<\/p>/) {
        $data->{address} = $2;
        $data->{locality}=$1;
    }

    my $data_list = $dom->find('div[class="item_full_right"]')->first->at('ul')->find('li');

    foreach (@{$data_list}) {
        my $t = $_->text;
        if ($t =~/площадь ([0-9,\.]*)\/([0-9,\.]*)\/([0-9,\.]*)/i){

            my $sq_t = $1;
            my $sq_l = $2;
            my $sq_k = $3;

            $sq_t =~ s/,/./;
            $sq_l =~ s/,/./;
            $sq_k =~ s/,/./;

            $sq_t = 0 + $sq_t;
            $sq_l = 0 + $sq_l;
            $sq_k = 0 + $sq_k;

            $data->{square_total} = $sq_t if ($sq_t > 0);
            $data->{square_living} = $sq_l if ($sq_l > 0);
            $data->{square_kitchen} = $sq_k if ($sq_k > 0);
        } elsif ($t =~/Участок ([0-9,\.]*)/) {
            my $sq_l = $1;
            $sq_l=~s/,/./;
            $data->{square_land} = $sq_l;
            $data->{square_land_type} = 'ar';
        } elsif ($t =~/Количество комнат: (\d{1,3})/) {
            $data->{rooms_count} = 0 + $1;
        } elsif ($t =~/(\d{0,3}) этаж из (\d{0,3})/) {
            $data->{floor} = $1;
            $data->{floors_count} = $2;
        } elsif ($t =~/Количество этажей: (\d{0,3})/) {
            $data->{floors_count} = $1;
        } elsif ($t =~/Тип комнат: (.+)/) {
            $data->{room_scheme_id} = _get_room_type($1);
        } elsif ($t =~/Санузел (.+)/) {
            $data->{bathroom_id} = _get_bathroom_type($1);
        } elsif ($t =~/Состояние (.+)/) {
            $data->{condition_id} = _get_condition_type($1);
        } elsif ($t =~/Количество (((лоджий)|(балконов)).+)/) {
            $data->{balcony_id} = _get_balcon_type($1);
        } else {
            $data->{house_type_id} = _get_house_type($t);

            $data->{ap_scheme_id} = _get_scheme_house($t);

            $data->{type_code} = 'apartment_new' if ($t =~/Новостройка/);

            $data->{type_code} = 'apartment_small' if ($t =~/Малосемейка/);
        }
    }

    #парсинг цены
    my $price_data = $dom->at('div[class="item_full_right"]')->at('p');
    if ($price_data) {
        if ($price_data->text =~ /Цена (.+) руб/){
            my $price = $1;
            $price =~ s/\s//g;
            $data->{owner_price} = 0 + $price/1000 if $price > 0;
        }
    }
    #определение текста объявления
    if ($dom->find('span[class="message_text"]')->first) {
        $data->{source_media_text} = $dom->find('span[class="message_text"]')->first->text;

        $data->{type_code} = 'cottage' if ($data->{source_media_text} =~ /коттедж/i && $data->{type_code} eq 'house');
        $data->{type_code} = 'townhouse' if ($data->{source_media_text} =~ /таунхаус/i && $data->{type_code} eq 'house');

        $data->{type_code} = 'dacha' if ($data->{source_media_text} =~ /(дача)|(дом)/i  && $data->{type_code} eq 'land');

        #уточняем размерность земель
        if ($data->{source_media_text} =~ /([\d,\.]{1,5}).{0,2}га/i) {
            if ($1 == $data->{square_land}) {
                $data->{square_land_type} = 'hectare';
            }
        }
    }

    #определение риэлтора
    my $t = $dom->at('span[class="fio"]')->at('a');
    if ($t) {
        $data->{mediator_company} = $t->text;
    } else {
        $data->{mediator_company} = $dom->at('span[class="fio"]')->text;
    }

    my $phone_text = $dom->find('span[class="phone"]')->first->text;
    my @phone_num = split(/,|;/, $phone_text);
    $data->{'owner_phones'} = \@phone_num;

    #извлекает ссылки на фотографии
    my $script = $dom->find('div[class="item_full_image_small"]')->first->at('ul')->find('li');
    if ($script) {
        foreach(@{$script}) {
            if ($_->at('a')->{href}=~/http:/){
                push @{$data->{photo_url}}, $_->at('a')->{href};
            } else {
                push @{$data->{photo_url}}, $media_data->{site_url} . $_->at('a')->{href};
            }
        }
    }

    return $data;
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

sub _get_type_code {
    my $title = shift;

    given($title) {
        when (/квартира/i) {
            return 'apartment';
        }
        when (/комната/i) {
            return 'room';
        }
        when (/дом/i) {
            return 'house';
        }
        when (/земельный участок/i) {
            return 'land';
        }
        when (/гараж/i) {
            return 'garage';
        }
        when (/коммерческая/i) {
            return 'other';
        }
    }

    return 'other';
}

sub _get_house_type {
  my $text = lc(shift);
  given ($text) {
      when (/монолит/ && /кирпич/) {
        return 7;
      }
      when (/монолит/) {
          return 2;
      }
      when (/кирпич/) {
        return 1;
      }
      when (/панель/) {
          return 3;
      }
      when (/брус/ || /бревно/) {
          return 5;
      }
      when (/(каркасно-засыпн(.{1,4}) дом)|(дом.{1}каркасно-засыпн)/) {
          return 6;
      }
      when (/(монолитно-кирпичн(.{1,4}) дом)|(дом.{1}монолитно-кирпичн)/) {
          return 7;
      }
      when (/дерев/) {
          return 4;
      }
  }
  return undef;
}

sub _get_room_type {
  my $text = shift;
  given ($text) {
      when (/смеж(.+)раздельн/) {
          return 6;
      }
      when (/смежн/) {
          return 4;
      }
      when (/раздельн/) {
          return 3;
      }
      when (/студ/) {
          return 1;
      }
      when (/икарус/) {
          return 5;
      }
  }
  return undef;
}

sub _get_balcon_type {
  my $text = lc(shift);
  given ($text) {
      when (/лоджий(.*)застек/) {
          return 5;
      }
      when (/балконов(.*)застек/) {
          return 6;
      }
      when (/лоджий(.*)/) {
          return 7;
      }
      when (/(лоджи. застеклен)|(застеклен.{0,4} лодж)/) {
          return 5;
      }
      when (/(балкон застеклен)|(застеклен.{0,4} балкон)/) {
          return 6;
      }
      when (/лоджия/) {
          return 3;
      }
      when (/балкон/) {
          return 2;
      }
  }
  return undef;
}

sub _get_condition_type {
  my $text = lc(shift);
  given ($text) {
      when (/евро.{0,1}ремонт/) {
          return 4;
      }
      when (/уд/) {
          return 9;
      }
      when (/хор/) {
          return 11;
      }
      when (/отл/) {
          return 12;
      }
      when (/(требуется ремонт)/) {
          return 6;
      }
      when (/(требуется косм.{0,10} ремонт)/) {
          return 7;
      }
      when (/(после строит)/) {
          return 1;
      }
      when (/(ремонт)/) {
          return 3;
      }
  }
  return undef;
}

sub _get_bathroom_type {
  my $text = lc(shift);
  given ($text) {
      when (/раздельн/) {
          return 3;
      }
      when (/совмещ/) {
          return 8;
      }
      when (/смежн/) {
          return 4;
      }
      when (/без удобств/) {
          return 1;
      }
      when (/без душа/) {
          return 7;
      }
      when (/c удобств/) {
          return 9;
      }
  }
  return undef;
}

sub _get_scheme_house {
  my $text = lc(shift);
  given ($text) {
      when (/хрущ/) {
          return 2;
      }
      when (/брежнев/) {
          return 3;
      }
      when (/сталин/) {
          return 1;
      }
      when (/новая/) {
          return 4;
      }
      when (/индивид/) {
          return 5;
      }
      when (/общеж/) {
          return 6;
      }
  }
  return undef;
}

1;
