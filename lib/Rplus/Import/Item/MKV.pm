package Rplus::Import::Item::MKV;

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


my $media_name = 'mkv';
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

    $media_data = Rplus::Class::Media->instance()->get_media($media_name, $location);;
    $ua = Rplus::Class::UserAgent->new(Rplus::Class::Interface->instance()->get_interface());

    my $data = {
        source_media => $media_name,
        source_url => $item_url,
        type_code => 'other',
        offer_type_code => 'sale',
        add_date => ''
    };

    parse_adv($data, $item_url);

    return $data;
}

sub parse_adv {
    my ($data, $item_url) = @_;

    my $source_url = $item_url;

    my $res = $ua->get_res($source_url, [
        Host => $media_data->{host},
        Referer => $media_data->{site_url}
    ]);
    my $dom = $res->dom;

    my $header = $dom->find('h1[class="offer-title"]')->first->at('small');

    if ($header =~ /аренда/i) {
        $data->{offer_type_code} = 'rent';
    }

    given ($header) {
        when(/\sкомнат/i) {
            $data->{type_code} = 'room';
        }
        when (/квартир/i) {
            $data->{type_code} = 'apartment';
        }
        when(/\sкомнат/i) {
            $data->{type_code} = 'room';
        }
        when (/дом/i) {
            $data->{type_code} = 'house';
        }
        when (/дач/i) {
            $data->{type_code} = 'dacha';
        }
        when (/коттедж/i) {
            $data->{type_code} = 'cottage';
        }

        when (/офис/i){
            $data->{type_code} = 'office_place';
        }
        when (/псн/i){
            $data->{type_code} = 'gpurpose_place';
        }
        when (/склад/i){
            $data->{type_code} = 'warehouse_place';
        }
        when (/торгового помещения/i){
            $data->{type_code} = 'market_place';
        }
        when (/земли/i){
            $data->{type_code} = 'land';
        }

        when (/студи/i){
            $data->{room_scheme_id} = 1;
        }
    }

    #извлекаем цену и тип аренды
    my $price_field = $dom->find('div[class="b-offer-price"] p[class="price"]')->first;
    my $price = $price_field->at('strong')->text;
    $price =~ s/\s//g;
    $data->{owner_price} = 0 + $price/1000 if $price > 0;

    if($price_field->at('small')){
      if($price_field->at('small')->text =~ /сутки/){
        $data->{rent_type} = 'short';
      } else {
        $data->{rent_type} ='long';
      }
    }
    say Dumper $data;

    #извлекаем дату добавления
    my $raw_date = $dom->find('div[class="b-date-and-sell-faster"] div[class="date"]')->first->at('div')->at('p')->text;
    my $dt = _parse_date($raw_date);
    $data->{add_date} = $dt->format_cldr("yyyy-MM-dd'T'HH:mm:ssZ");

    $dom->find('div[class="options-wrapper"] ul li')->each (sub {

        #парсинг адреса/города
        if($_->at('label')->text =~ /Адрес:/){
            my $idx = 0;
            my @locality = '';
            my @addr = '';

            $_->at('p')->find('a')->each(sub {
                say $_;
                if ($idx < 2) {
                    push @locality, $_->text;
                } else {
                    push @addr, $_->text;
                }
                $idx ++;
            });
            $data->{locality} = join ', ', @locality;
            $data->{address} = join ', ', @addr;
        }

        #парсинг количества комнат
        elsif ($_-> at('label')->text  =~/Комнаты:/){
            $data->{rooms_count} =  0 + $1 if($_->at('p')=~ /(\d{1,3})-комнат/);
        }

        #парсинг этажа и этажности
        elsif ($_ ->at('label')->text =~/Этаж:/){
          if($_->at('p')->text =~ /(\d{1,3}) из (\d{1,3})/){
            $data->{floor} = $1;
            $data->{floors_count} = $2;
          } elsif ($_->at('p')->text =~ /(\d{1,3})/){
              $data->{floor} = $1;
          }
        }

        elsif ($_ ->at('label')->text =~/Этажность:/){
          if ($_->at('p')->text =~ /(\d{1,3})/){
              $data->{floors_count} = $1;
          }
        }

        #определение типа здания
        elsif ($_ ->at('label')->text =~/Дом:/){
          $data->{house_type_id} = get_house_type($_->at('p')->text);
        }

        #санузла и балкона
        elsif ($_ ->at('label')->text =~/Планировка:/){
            $data->{bathroom_id} = get_bathroom_type($_->at('p')->text);
            $data->{balcony_id} = get_balcon_type($_->at('p')->text);
        }

        #определение состояния
        elsif ($_ ->at('label')->text =~/Состояние:/){
            $data->{condition_id} = get_condition_type($_->at('p')->text);
        }

        #парсинг площади
        elsif ($_ ->at('label')->text =~/Площадь:/){
            $data->{square_total} = $1 if($_->at('p')->text =~ /([0-9\.]+) м/);
            $data->{square_kitchen} = $1 if($_->at('p')->text =~ /кухня ([0-9\.]+) м/);
            $data->{square_living} = $1 if($_->at('p')->text =~ /жилая ([0-9\.]+) м/);
            $data->{square_land} = $1 if($_->at('p')->text =~ /([0-9\.]+)+ соток/);
            $data->{square_land_type} = 'ar' if($data->{square_land});
        }
    });

    #извлекаем текст обявления
    my $text = $dom->find('div[class="b-content-left-col"]')->first;
    if($text){
      $data->{source_media_text} = $text->at('p')->text;
      $data->{ap_scheme_id} = get_scheme_house($data->{source_media_text});
      $data->{type_code} = 'apartment_small' if ($data->{source_media_text} =~/малосемейка/i);
      $data->{bathroom_id} = get_bathroom_type($data->{source_media_text});
    }

    #определение риэлтора
    my @phone_num;
    my $own_info = $dom->find('div[class="b-phone-info"]')->first->at('p');
    my $raw_phone = $own_info->at('span')->at('span')->at('a')->text;
    push @phone_num, $raw_phone;

    if($own_info->at('a')){
        my $seller = $own_info->at('a')->text;
        $data->{mediator_company} = $seller;
    }

    $data->{owner_phones} = \@phone_num;

    #извлекает ссылки на фотографии
    my $trigger=0;
    $dom->find('a[class="m-tgb-replaceableLink slider-container"] img')->each(sub {
      my $photo;
      if($trigger == 0){
        $photo = $_->{src};
      } else{
        $photo = $_->attr('data-src');
      }
      $photo =~ s/320x240/1024x768/;
      push @{$data->{photo_url}},  $photo;
        $trigger++;
    });

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

sub get_house_type {
  my $text = lc(shift);
  given ($text) {
      when (/монолит-кирпич/) {
        return 7;
      }
      when (/монолит/) {
          return 2;
      }
      when (/кирпич /) {
        return 1;
      }
      when (/панель/) {
          return 3;
      }
      when (/дерев/) {
          return 4;
      }
  }
  return undef;
}

sub get_balcon_type {
  my $text = lc(shift);
  given ($text) {
      when (/лоджи(.{1,5})стек/) {
          return 5;
      }
      when (/балконов(.*)застек/) {
          return 6;
      }
      when (/лоджии(.*)/) {
          return 7;
      }
      when (/(лоджи(.{1,10})застеклен)|(застеклен(.{1,10})лодж)/) {
          return 5;
      }
      when (/(балко(.{1,10})застеклен)|(застеклен(.{1,10})балкон)/) {
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

sub get_bathroom_type {
  my $text = lc(shift);
  given ($text) {
      when (/раздельн/ || /санузел 2 и более/) {
          return 3;
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

sub get_condition_type {
  my $text = lc(shift);
  given ($text) {
      when (/евроремонт/ || /дизайнерский/) {
          return 4;
      }
      when (/первичная отделка/) {
          return 9;
      }
      when (/хор/) {
          return 11;
      }
      when (/отл/) {
          return 12;
      }
      when (/(требует ремонта)/) {
          return 6;
      }
      when (/(требуется косм.{0,10} ремонт)/) {
          return 7;
      }
      when (/(без отделки)/) {
          return 1;
      }
      when (/(не требует ремонта)/) {
          return 3;
      }
  }
  return undef;
}

sub get_scheme_house {
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
      when (/общежити/) {
          return 6;
      }
  }
  return undef;
}

1;
