package Rplus::Import::Item::Present;

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


my $media_name = 'present_site';
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

    # дата
    my $data_str = trim($dom->at('div[class="notice-card"]')->at('div[class="fields-top"]')->all_text);
    if ($data_str =~ /^добавлено:\s+(.+)$/i) {
        my $dt = _parse_date($data_str);
        $data->{add_date} = $dt->datetime();
    }

    my $breadcrumbs_str = trim($dom->at('div[class="breadcrumbs"]')->all_text);
    say $breadcrumbs_str;
    # тип предложения
    if ($breadcrumbs_str =~ /сдам/i) {
        $data->{offer_type_code} = 'rent';
    }

    # тип недвижимости
    $data->{type_code} = _get_type_code($breadcrumbs_str);

    if ($breadcrumbs_str =~ /посуточно/i) {
        $data->{rent_type} = 'short';
    }

    #парсим текст объявления
    $data->{source_media_text} = $dom->find('div[class="notice-card"] div[class="text"]')->first->text;

    #найдём поля с данными о недвижимости
    $dom->find('div[class="notice-card"] div[class="fields"]')->first->children->each (sub {

      #извлечение цены
      if($_->at('strong')->text =~ /Цена:/){
          my $price = $_->at('span')->text;
          $price =~ s/\D//g;
          $data->{owner_price} = $price / 1000 if $price > 0;
      }

      #извлечение арендной платы
      elsif ($_->at('strong')->text =~ /Арендная плата/){
            my $price = $_->at('span')->text;
            $price =~ s/\D//g;;
            $data->{owner_price} = $price / 1000;
      }

      #определяем новостройку
      elsif($_->at('strong')->text =~ /Вторичный рынок:/){
          #$data->{type_code} = 'apartment_new' if ($_->at('span')->text =~ /да/i);
      }

      #парсинг адреса
      if($_->at('strong')->text =~ /Улица\/переулок:/){
          $data->{address}= $_->at('span')->text;
      }

      #парсинг города
      if($_->at('strong')->text =~ /Населенный пункт:/){
          $data->{locality}= $_->at('span')->text;
      }

      #парсинг количества комнат
      elsif ($_->at('strong')->text =~ /Количество комнат:/){
          if($_->at('span')->text =~ /2-уровневая/){
              $data->{levels_count} = 2;
          } else{
            $data->{rooms_count} =  0 + $_->at('span')->text;
          }
      }

      #парсинг количества комнат аренды
      elsif ($_->at('strong')->text =~ /Объект аренды/){
        if($_->at('span')->text=~ /(\d).+комн/){
          $data->{rooms_count} =  0 + $1;
        }
        elsif($_->at('span')->text=~ /Малосем/){
          $data->{type_code} =  'apartment_small';
        }
      }

      #парсинг планировка
      elsif ($_->at('strong')->text =~ /Планировка:/){
          $data->{ap_scheme_id} =  get_scheme_house($_->at('span')->text);
      }

      #парсинг этажа
      elsif ($_->at('strong')->text =~ /Этаж:/){
          $data->{floor} = 0 + $_->at('span')->text if ($_->at('span')->text =~ /\d{1,3}/);
      }

      #парсинг этажности
      elsif ($_->at('strong')->text =~ /Этажность/){
          $data->{floors_count} = 0 + $_->at('span')->text if ($_->at('span')->text =~ /\d{1,3}/);
      }

      #парсинг типа здания
      elsif ($_->at('strong')->text =~ /Материал стен:/){
          $data->{house_type_id} = _get_house_type_id($_->at('span')->text);
      }

      #определение состояния
      elsif ($_->at('strong')->text =~ /Состояние:/){
          $data->{condition_id} = _get_condition_id($_->at('span')->text);
      }

      #парсинг общей площади
      elsif ($_->at('strong')->text =~ /Площадь (общая)|(\(кв\. м\))/){
         my $sq =  $_->at('span')->text;
         if($_->at('span')->text =~ /\d{1,5}/){
           $sq=~s/,/\./;
           $data->{square_total} = 0 + $sq;
         }
      }

      #парсинг площади дома
      elsif ($_->at('strong')->text =~ /Площадь дома/){
        my $sq =  $_->at('span')->text;
        if($_->at('span')->text =~ /\d{1,5}/){
          $sq=~s/,/\./;
          $data->{square_total} = 0 + $sq;
        }
      }

      #парсинг жилой площади
      elsif ($_->at('strong')->text =~ /Площадь жилая/){
        my $sq =  $_->at('span')->text;
        if($_->at('span')->text =~ /\d{1,5}/){
          $sq=~s/,/\./;
          $data->{square_living} = 0 + $sq;
        }
      }

      #парсинг площади кухни
      elsif ($_->at('strong')->text =~/Площадь кухни/){
        my $sq =  $_->at('span')->text;
        if($_->at('span')->text =~ /\d{1,5}/){
          $sq=~s/,/\./;
          $data->{square_kitchen} = 0 + $sq;
        }
      }

      #парсинг участка
      elsif ($_->at('strong')->text =~ /Площадь (участка)|(\(сотки\))/){
        my $sq =  $_->at('span')->text;
        if($_->at('span')->text =~ /\d{1,5}/){
          $sq=~s/,/\./;
          $data->{square_land} = 0 + $sq;
          $data->{square_land_type} = 'ar';
        }
      }

      #определение балконов/лоджий
      elsif ($_->at('strong')->text =~ /Балкон\/лоджия/){
          $data->{balcony_id} = get_balcon_type($_->at('span')->text);
      }
    });

    #парсим телефон
    my $phone_text=$dom->find('div[class="notice-card"] div[class="phone"]')->first;
    my @phone;
    if($phone_text){
        push @phone, $phone_text->text;
    }
    $data->{owner_phones}=\@phone;

	  my $do = $dom->find('div[class="lightbox images"]');
	  $do->first->find('a[target="_blank"]')->each ( sub {
		    my $img_url = $media_data->{site_url} . $_->{'href'};
		      push @{$data->{photo_url}}, $img_url;
	});

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
    } elsif ($date =~ /(\d{1,2}):(\d{1,2})/) {
        $res = $parser->parse_datetime("$year-$mon-$mday $1:$2");
        # substr 1 day
        $res->subtract(days => 1);
    } elsif ($date =~ /(\d+) (\w+)/) {
        my $a_mon = _month_num($2);
        my $a_year = $year;
        if ($a_mon > $mon) { $a_year -= 1; }
        $res = $parser->parse_datetime("$a_year-$a_mon-$1 12:00");
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
    my $breadcrumbs_str = lc(shift);

    #cottage
    #townhouse
    #apartment_new
    #office
    #production_place

    given ($breadcrumbs_str) {
        when (/квартиры/i) {
            return 'apartment';
        }
        when (/дома/i) {
            return 'house';
        }
        when (/комнаты/i) {
            return 'room';
        }
        when (/малосемейки/i) {
            return 'apartment_small';
        }
        when (/участки/i) {
            return 'land';
            #dacha
        }
        when (/гаражи/i) {
            return 'garage';
        }

        when (/здания/i) {
            return 'building';
        }
        when (/торговые площади/i) {
            return 'market_place';
        }
        when (/офисные помещения/i) {
            return 'office_place';
        }
        when (/площади под автобизнес/i) {
            return 'autoservice_place';
        }
        when (/склады, базы/i) {
            return 'warehouse_place';
        }
        when (/Помещения под сферу услуг/i) {
            return 'service_place';
        }
        when (/Помещения свободного назначения/i) {
            return 'gpurpose_place';
        }
    }

    return undef;
}

sub _get_house_type_id {
  my $text = lc(shift);
  given ($text) {
      when (/монолитно-кирпич/) {
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
      when (/дерев/) {
          return 4;
      }
      when (/брус/) {
          return 5;
      }
  }
  return undef;
}

sub _get_room_sch_id {
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

sub _get_balcony_id {
  my $text = lc(shift);
  given ($text) {
      when (/балкон \+ лоджия/) {
        return 4;
      }
      when (/лоджия/) {
          return 3;
      }
      when (/балкон/) {
          return 2;
      }
      when (/без/) {
          return 1;
      }
  }
  return undef;
}

sub _get_condition_id {
  my $text = lc(shift);
  given ($text) {
      when (/евроремонт/) {
          return 4;
      }
      when (/удовлетворит/) {
          return 9;
      }
      when (/хорошее/) {
          return 11;
      }
      when (/отличное/) {
          return 12;
      }
      when (/(требуется капитальный ремонт)/) {
          return 6;
      }
      when (/(требуется косметический ремонт)/) {
          return 7;
      }
      when (/(после строителей)/) {
          return 1;
      }
      when (/(социальный)/) {
          return 2;
      }
  }
  return undef;
}

sub _get_scheme_id {
  my $text = lc(shift);
  given ($text) {
      when (/хрущевка/) {
          return 2;
      }
      when (/брежневка/ || /улучшен/) {
          return 3;
      }
      when (/сталинка/) {
          return 1;
      }
      when (/новая/) {
          return 4;
      }
      when (/индивид/) {
          return 5;
      }
  }
  return undef;
}

1;
