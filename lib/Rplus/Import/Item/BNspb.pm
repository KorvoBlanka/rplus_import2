package Rplus::Import::Item::BNspb;

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


my $media_name = 'bnspb';
my $media_data;
my $parser = DateTime::Format::Strptime->new(pattern => '%Y-%m-%d %H:%M:%S');
my $ua;


sub get_item {
    my ($location, $item_url) = @_;

    say 'loading ' . $media_name . ' - ' . $location . ' - ' . $item_url;
    my $data = _get_item($location, $item_url);
    say Dumper $data;

    #my $realty = Rplus::Model::Result->new(metadata => to_json($data), media => $media_name, location => $location)->save;
    #say 'saved ' . $realty->id;
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

    my $title = $dom->at('h1[class="head_obj"]');
    my @tp = split /,/, $title;
    my $r_type = $tp[0];

    if ($r_type =~ /квартира/i) {
        $data->{'type_code'} = 'apartment';
    } elsif ($r_type =~ /комната/i) {
        $data->{'type_code'} = 'room';
    } elsif ($r_type =~ /участок/i) {
        $data->{'type_code'} = 'land';
    } elsif ($r_type =~ /коттедж/i) {
        $data->{'type_code'} = 'cottage';
    } elsif ($r_type =~ /таунхаус/i) {
        $data->{'type_code'} = 'townhouse';
    } elsif ($r_type =~ /дача/i) {
        $data->{'type_code'} = 'dacha';
    } elsif ($r_type =~ /дом/i) {
        $data->{'type_code'} = 'house';
    } elsif ($r_type =~ /часть дома/i) {
        $data->{'type_code'} = 'house';
    }

    $dom->find('tr[valign="top"]')->each(sub {
        my $n = $_->at('td');
        my $nn = $n->next;

        if ($n->text =~ /^цена:/i) {
            my $price = trim($nn->all_text);
            $price =~ s/\D//g;
            $data->{'owner_price'} = $price;
        } elsif ($n->text =~ /^субъект:/i) {
            my $subj = trim($nn->all_text);
            unless ($subj eq 'частное') {
                $data->{mediator_company} = $subj;
            }
        } elsif ($n->text =~ /^телефон:/i) {
            my @owner_phones = ();
            my $t = $nn->at('a[class="show_phone"]');
            if ($t) {
                my $raw_phone = $t->attr('phone');
                push @owner_phones, $raw_phone;
            }
            $data->{'owner_phones'} = \@owner_phones;
        } elsif ($n->text =~ /^вид сделки:/i) {
            my $offer_type = trim($nn->all_text);
            if ($offer_type =~ /продажа/) {
                $data->{'offer_type_code'} = 'sale';
            } else {
                $data->{'offer_type_code'} = 'rent';
            }
            # short / long ?
        } elsif ($n->text =~ /^район:/i) {
        } elsif ($n->text =~ /^метро:/i) {
        } elsif ($n->text =~ /^адрес:/i) {
            $data->{'address'} = $nn->all_text;
        } elsif ($n->text =~ /^номер дома/i) {        # ?

        } elsif ($n->text =~ /^корпус или дробь/i) {  # ?

        } elsif ($n->text =~ /^комнат:/i) {
            my $tnum = $nn->all_text;
            $tnum =~ s/\D//g;
            $data->{'rooms_count'};
        } elsif ($n->text =~ /^этаж\/этажность:/i) {
            my $tnum = $nn->all_text;
            if ($tnum =~ /(\d{1,2})\/(\d{1,2})/) {
                $data->{'floor'} = $1;
                $data->{'floors_count'} = $2;
            } else {
                $tnum =~ s/\D//g;
                if ($tnum) {
                    $data->{'floors_count'} = $tnum;
                }
            }
        } elsif ($n->text =~ /^площадь участка/i) {
            my $tnum = $nn->all_text;
            if ($tnum =~ /(\d+(?:.\d+)?)/) {
                $data->{'square_land'} = $1;
                $data->{'square_land_type'} = 'ar';
            }
        } elsif ($n->text =~ /^площадь (м2)/i) {
            my $tnum = $nn->all_text;
            if ($tnum =~ /(\d+(?:.\d+)?)/) {
                $data->{'square_total'} = $1;
            }
        } elsif ($n->text =~ /^общая пл/i) {
            my $tnum = $nn->all_text;
            if ($tnum =~ /(\d+(?:.\d+)?)/) {
                $data->{'square_total'} = $1;
            }
        } elsif ($n->text =~ /^пл\. кухни/i) {
            my $tnum = $nn->all_text;
            if ($tnum =~ /(\d+(?:.\d+)?)/) {
                $data->{'square_kitchen'} = $1;
            }
        } elsif ($n->text =~ /^жилая пл/i) {
            my $tnum = $nn->all_text;

            my @sq_p = split /\+/, $tnum;
            my $sq_summ = 0;
            for my $sq_v (@sq_p) {
                if ($sq_v =~ /(\d+(?:.\d+)?)/) {
                    $sq_summ += $1;
                }
            }

            $data->{'square_living'} = $sq_summ;

        } elsif ($n->text =~ /^тип дома:/i) {
            my $tval = $nn->all_text;
            given ($tval) {
                when (/блочно-монолитный/i) {
                    $data->{'house_type_id'} = 2;
                }
                when (/блочный/i) {
                    $data->{'house_type_id'} = 8;
                }
                when (/брежневский/i) {
                    $data->{'ap_scheme_id'} = 4;
                }
                when (/деревянный/i) {
                    $data->{'house_type_id'} = 4;
                }
                when (/индивидуальный/i) {
                    $data->{'ap_scheme_id'} = 5;
                }
                when (/кирпично-монолитный/i) {
                    $data->{'house_type_id'} = 7;
                }
                when (/кирпичный/i) {
                    $data->{'house_type_id'} = 1;
                }
                when (/коттедж/i) {
                }
                when (/монолитно-панельный/i) {
                    $data->{'house_type_id'} = 2;
                }
                when (/монолит/i) {
                    $data->{'house_type_id'} = 2;
                }
                when (/панельный/i) {
                    $data->{'house_type_id'} = 3;
                }
                when (/сталинский/i) {
                    $data->{'ap_scheme_id'} = 1;
                }
                when (/хрущевский/i) {
                    $data->{'ap_scheme_id'} = 2;
                }
            }
        } elsif ($n->text =~ /^санузел:/i) {
            my $tval = $nn->all_text;
            say $tval;
            given ($tval) {
                when (/без ванны/i) {
                    $data->{'bathroom_id'} = 1;
                }
                when (/ванна на кухне/i) {
                    $data->{'bathroom_id'} = 10;
                }
                when (/душ на кухне/i) {
                    $data->{'bathroom_id'} = 11;
                }
                when (/душ/i) {
                    $data->{'bathroom_id'} = 6;
                }
                when (/раздельный/i) {
                    $data->{'bathroom_id'} = 3;
                }
                when (/совмещенный/i) {
                    $data->{'bathroom_id'} = 8;
                }
                when (/два/i) {
                    $data->{'bathroom_id'} = 4;
                }
                when (/три/i) {
                    $data->{'bathroom_id'} = 4;
                }
            }
        } elsif ($n->text =~ /^издание:/i) {
        } elsif ($n->text =~ /^дата размещения:/i) {
            my $dt = _parse_date($nn->all_text);
            $data->{'add_date'} = $dt->$dt->format_cldr("yyyy-MM-dd'T'HH:mm:ssZ");
        }
    });

    return $data;
}

sub _parse_date {
    my $date = lc(shift);

    my $res;
    my $dt_now = DateTime->now();

    if ($date =~ /(\d{1,2})\.(\d{1,2})\.(\d{1,4})/) {
        $res = $parser->parse_datetime("$3-$2-$1 00:00:00");
        if ($res > $dt_now) {
            # substr 1 day
            $res->subtract(days => 1);
        }
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
