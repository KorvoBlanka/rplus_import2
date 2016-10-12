package Rplus::Import::Item::BN;

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


my $media_name = 'bn';
my $media_data;
my $parser = DateTime::Format::Strptime->new(pattern => '%d.%m.%Y');
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

    my $title = $dom->at('section[class="round_gr detail"]')->at('h1')->text;

    if ($title =~ /продажа/i) {
      $data->{offer_type_code} = 'sale';
    } else {
      $data->{offer_type_code} = 'rent';
    }

    if ($title =~ /посуточно/) {
      $data->{rent_type} = 'short';
    } else {
      $data->{rent_type} = 'long';
    }

    # rooms count and type_code
    given($title) {
      when (/(\d+)-комнатной/i) {
        $data->{type_code} = 'apartment';
        $data->{rooms_count} = $1;
      }

      when (/квартиры в новостройке/i) {
        $data->{type_code} = 'apartment_new';
      }

      when (/элитной недвижимости/i) {
        $data->{type_code} = 'apartment';
      }

      when (/комнаты/i) {
        $data->{type_code} = 'room';
      }

      when (/дома/i) {
        $data->{type_code} = 'house';
      }

      when (/коттеджа/i) {
        $data->{type_code} = 'cottage';
      }

      when (/участка/i) {
        $data->{type_code} = 'land';
      }

      when (/офиса/i) {
        $data->{type_code} = 'office_place';
      }

      when (/помещения в сфере услуг/i) {
        $data->{type_code} = 'service_place';
      }

      when (/помещения различного назначения/i) {
        $data->{type_code} = 'gpurpose_place';
      }

      when (/отдельно стоящего здания/i) {
        $data->{type_code} = 'building';
      }

      when (/производственно-складского помещения/i) {
        $data->{type_code} = 'production_place';
      }
    }

    my $t = $dom->at('table[class~="adr"]')->find('td');
    if ($t) {
      $data->{address} = $t->[1]->text;
    }

    $t = $dom->at('div[id~="description"]');
    if ($t) {
      $data->{source_media_text} = $t->text;
    }

    my $subject_name;
    $t = $dom->at('div[class="table"]')->find('dl');
    $t->each(sub {
      my $h = trim($_->at('dt')->text);

      my $dn = $_->at('dd');
      return unless $dn;
      my $d = trim($dn->all_text);
      $d =~ s/[\h\v]+/ /g;

      say $h . ' - ' . $d;

      given($h) {

        when (/цена/i) {
          my $price = $d;
          $price =~ s/\D//g;
          $data->{owner_price} = $price / 1000;
        }

        when (/продает/i) {
          $subject_name = $d;
        }

        when (/сдает/i) {
          $subject_name = $d;
        }

        when (/телефон/i) {
          my @owner_phones;
          for my $x (split /[.,;:]/, $d) {
            if (my $phone_num = $x) {
              push @owner_phones, $phone_num;
            }
          }
          $data->{owner_phones} = \@owner_phones;
        }

        when (/регион/i) {
          $data->{locality} = $d;
        }

        when (/этаж/i) {
          if ($d =~ /(\d+) этаж в (\d+)-этажном доме/) {
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
        when (/кол-во комнат/i) {
          if ($d =~ /(\d+)/) {
            $data->{rooms_count} = $1;
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
        when (/дата обновления/i) {
            my $ut = $parser->parse_datetime($d);
            say $ut;
            $data->{add_date} = $ut->datetime();
        }
      }
    });

    if ($subject_name !~ /частное/) {
      foreach (@{$data->{'owner_phones'}}) {
          $data->{mediator_company} = $subject_name;
      }
    }

    my @photos;
    $dom->find('div[class="wrap"] img')->each(sub {
        my $img_url = $_->attr("src");
        $img_url =~ s/s.jpg/b.jpg/;
        push @photos, $img_url;
    });
    $data->{photo_url} = \@photos;

    return $data;
}

1;
