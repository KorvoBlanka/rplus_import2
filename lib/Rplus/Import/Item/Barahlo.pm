package Rplus::Import::Item::Barahlo;

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


my $media_name = 'barahlo';
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

    my $date_str = $dom->at('table[class="show_ob"]')->at('td[class="td1"]')->at('p[class="grey"]')->text;
    if ($date_str =~ /^(.+)\s+объявление/) {
        my $dt = _parse_date($1);
        $data->{add_date} = $dt->format_cldr("yyyy-MM-dd'T'HH:mm:ssZ");
    }

    my $ad_header = $dom->find('table[class="ob_header"]')->first->at('tr')->at('td')->next->at('h1')->text;
    $data->{type_code} = _get_realty_type_code($ad_header);

    if ($ad_header =~ /сдам/i) {
        $data->{offer_type_code} = 'rent';
    }

    if($data->{source_url} =~ /\/(219|286|219)\//){
        $data->{rent_type} = 'short';
    }

    my $data_list = $dom->find('td[class="td1"]')->first->find('p');

    my $list = 0;
    #проверяем первую запись на наличие в ней стоимости
    unless($data_list->[0]->text){
        if($data_list->[0]->at('strong')->text =~ /Стоимость: (\d{1,}) руб/){
            $data->{owner_price} = $1/1000 if $1 > 0;
            $list++;
        }
    }

    do{
        if ($data_list->[$list] =~ /^<p>Общая площадь:/){
            if($data_list->[$list]->at('strong')->text =~ /(\d+) кв.м./){
                $data->{square_total} = $1 if $1 > 0;
            } elsif ($data_list->[$list]->at('strong')->text =~ /(\d+) (сот|га)/) {
                $data->{square_land} = $1 if $1 > 0;
                if ($2 =~ /сот/){
                    $data->{square_land_type} = 'ar';
                }
                else {
                    $data->{square_land_type} = 'hectare';
                }
            }
        }
        elsif ($data_list->[$list] =~ /^<p>Кол-во комнат:/){
            $data->{rooms_count} =  0 + $data_list->[$list]->at('strong')->text;
        }
        elsif ($data_list->[$list] =~ /^<p>Район, адрес:/){
            $data->{address} = $data_list->[$list]->at('strong')->text;
        }
        elsif ($data_list->[$list] =~ /^<p>Ссылка на описание:/){

        }
        else {
            if($data->{type_code} eq 'apartment' && $data_list->[$list] =~ /малосемейк/){
                $data->{type_code} = 'apartment_small';
            }
            if ($data_list->[$list] =~ /.*(\s|,|\.)(\d{1,3}).{0,6}этаж(ей|ое|ного|ом)/){
                $data->{floors_count} = $2;
            }

            if($data->{type_code} !~ /(house)|(cottage)|(dacha)|(building)/){
                if ($data_list->[$list] =~ /.*(\s|,|\.)(\d{1,3}).{0,6}этаж(е|\W)/){
                    $data->{floor} = $2;
                }
            }

            $data->{source_media_text} = $data_list->[$list]->all_text;

            $data->{house_type_id} = _get_house_type($data_list->[$list]);

            $data->{room_scheme_id} = _get_room_type($data_list->[$list], $data);

            $data->{balcony_id} = _get_balcon_type($data_list->[$list]);

            $data->{bathroom_id} = _get_bathroom_type($data_list->[$list]);

            $data->{condition_id} = _get_condition_type($data_list->[$list]);

            $data->{ap_scheme_id} = _get_scheme_house($data_list->[$list]);
        }

        $list++;
    } while ($data_list->[$list] !~ /^<p>Город:/);

    $data->{locality} =  $data_list->[$list]->at('strong')->text;

    get_phone_number($dom, $data);

    my $script = $dom->find('td[class="td1"]')->first->parent->at('td')->next->at('div')->at('script');
    my $dir;
    my @list;
    if($script) {
        if($script =~ /imagesDir = '(.+)';/){
            $dir = $1;
            if($script =~ /imagesList = \['(.+)'\];/){
                @list = split(/', '/, $1);
            }
        }
        for(my $i=0; $i < scalar @list; ++$i){
            push @{$data->{photo_url}}, 'http://www.barahla.net/'.$dir.'big/'.$list[$i].'.jpg';
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
            $res->subtract(days => 1);
        }
    } elsif ($date =~ /вчера в (\d{1,2}):(\d{1,2})/) {
        $res = $parser->parse_datetime("$year-$mon-$mday $1:$2");
        # substr 1 day
        $res->subtract(days => 1);
    } elsif ($date =~ /позавчера в (\d{1,2}):(\d{1,2})/) {
        $res = $parser->parse_datetime("$year-$mon-$mday $1:$2");
        # substr 1 day
        $res->subtract(days => 2);
    } elsif ($date =~ /(\d{1,2}) (\w{1,}) (\d{4}) г. в (\d{1,2}):(\d{1,2})/) {
        my $a_mon = _month_num($2);
        $res = $parser->parse_datetime("$3-$a_mon-$1 $4:$5");
    } else {
        $res = $dt_now;
    }

    $res->set_time_zone('local');

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

sub get_phone_number {
    my ($dom, $data) = @_;
    my $pnone_str;
    my @phones = ();

    eval{
        my $code = '';
        do {
            my $author_ob = $dom->find('table[class="author_ob"]')->first->at('tr')->next->at('td')->next->at('p')->next->next->at('span')->at('a');

            if($author_ob->attr('onclick') =~ /key: '(\w+)'/) {
                my $tx = $ua->{ua}->post($media_data->{site_url} . '/ajax/getPhones.php?rand='.rand() => form => {key => $1, br => 'BR_TAG'},);
                $code = $tx->res->code;
                $pnone_str = $tx->{res}->{content}->{asset}->{content};
            }
            sleep 1;
        } while($code != 200 || $pnone_str =~ /error/);

        my @pa = split /;/, $pnone_str;
        for my $el (@pa) {
            $el =~ s/\D+//g;
            push @phones, $el;
        }

        1;
    } or do {
        say $@;
    };
    $data->{'owner_phones'} = \@phones;
}

sub _get_realty_type_code {
    my $text = lc(shift);
    given ($text) {
        when (/квартир/) {
            if($text =~ /новостр/){
                return 'apartment_new';
            } else{
                return 'apartment';
            }
        }
        when (/комнат/) {
            return 'room';
        }
        when (/малосемей/) {
            return 'apartment_small';
        }
        when (/коттедж/) {
            return 'cottage';
        }
        when (/дом/) {
            return 'house';
        }
        when (/дач/) {
            return 'dacha';
        }
        when (/гараж/) {
            return 'garage';
        }
        when (/нежило/) {
            return 'gpurpose_place';
        }
        when (/автосервис/) {
            return 'autoservice_place';
        }
        when (/(базу)|(склад)/) {
            return 'warehouse_place';
        }
        when (/(торгов)|(павильон)|(магазин)/) {
            return 'market_place';
        }
        when (/(офис)/) {
            return 'office_place';
        }
        when (/(здание)/) {
            return 'building';
        }
        when (/(многофункциональное)|(универсальное)/) {
            return 'service_place';
        }
        when (/(завод)|(цех)|(производств)/) {
            return 'production_place';
        }
        when (/(гостиниц)|(кафе)|(ресторан)|(салон)|(бизнес)/) {
            return 'other';
        }
        when (/хозяйств/) {
            return 'land';
        }
    }
    return 'other';
}

sub _get_house_type {
  my $text = lc(shift);
  given ($text) {
      when (/(кирпичн(.{1,4}) дом)|(дом.{1}кирпичн)/) {
        return 1;
      }
      when (/(монолитн(.{1,4}) дом)|(дом.{1}монолит)/) {
          return 2;
      }
      when (/(панельн(.{1,4}) дом)|(дом.{1}панельн)/) {
          return 3;
      }
      when (/(деревян(.{1,4}) дом)|(дом.{1}деревян)/) {
        return 5 if (/брус/);
        return 4;
      }
      when (/брус/) {
          return 5;
      }
      when (/(каркасно-засыпн(.{1,4}) дом)|(дом.{1}каркасно-засыпн)/) {
          return 6;
      }
      when (/(монолитно-кирпичн(.{1,4}) дом)|(дом.{1}монолитно-кирпичн)/) {
          return 7;
      }
  }
  return undef;
}

sub _get_room_type {
  my ($text, $data) = @_;
  given ($text) {
      when ($data->{type_code}=~/(apartment)/ && /студия/) {
          return 1;
      }
      when (/кухня-костин/) {
          return 2;
      }
      when (/(раздельн(.{1,4})комнат)|(комнат.{1,3}раздельн)/) {
          return 3;
      }
      when (/(смежн(.{1,4})комнат)|(комнат.{1,3}смежн)/) {
          return 4;
      }
      when (/(смежно-раздельн(.{1,4})комнат)|(комнат.{1,3}смежно-раздельн)/) {
          return 4;
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
      when (/балкон/ && /лоджи/) {
          return 4;
      }
      when (/лоджии/) {
          return 8;
      }
      when (/балкона/) {
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

sub _get_bathroom_type {
  my $text = lc(shift);
  given ($text) {
      when (/(сануз.{0,4} раздельн)|(раздельн.{0,6} сануз)/) {
        if ($text=~/санузла/){
          return 5;
        }
        else{
          return 3;
        }

      }
      when (/(сануз.{0,4} совмещ)|(совмещ.{0,6} сануз)/) {
          return 8;
      }
      when (/(сануз.{0,4} смежн)|(смежн.{0,6} сануз)/) {
          return 4;
      }
      when (/туалет/) {
        if($text=~/(душ)/){
          return 6;
        } else{
          return 7;
        }
      }
      when (/c удобств/) {
          return 9;
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
      when (/соц.{0,8}ремонт/) {
          return 2;
      }
      when (/дизайнер.{0,5}ремонт/) {
          return 5;
      }
      when (/(уд.{0,17}состоян)|(состоян.{0,5} уд)/) {
          return 9;
      }
      when (/(норм.{0,7}состоян)|(состоян.{0,5} норм)/) {
          return 10;
      }
      when (/(хор.{0,6}состоян)|(состоян.{0,5} хор)/) {
          return 11;
      }
      when (/(отл.{0,7}состоян)|(состоян.{0,5} отл)/) {
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

sub _get_scheme_house {
  my $text = lc(shift);
  given ($text) {
      when (/хрущ/) {
          return 2;
      }
      when (/(брежнев)|(улучш.{0,6}планир)|(планир.{0,5}улучш)/) {
          return 3;
      }
      when (/сталин/) {
          return 1;
      }
      when (/(нов.{0,5}планир)|(планир.{0,5}новая)/) {
          return 4;
      }
      when (/(индивид.{0,7}планир)|планир.{0,5}индивид/) {
          return 5;
      }
      when (/общежит/) {
          return 6;
      }
  }
  return undef;
}

1;
