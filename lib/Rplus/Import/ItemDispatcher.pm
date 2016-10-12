package Rplus::Import::ItemDispatcher;

use Rplus::Modern;
use Rplus::Import::Item::Avito;
use Rplus::Import::Item::Irrru;
use Rplus::Import::Item::Farpost;
use Rplus::Import::Item::CIAN;
use Rplus::Import::Item::BN;
use Rplus::Import::Item::BNspb;
use Rplus::Import::Item::MKV;
use Rplus::Import::Item::Present;
use Rplus::Import::Item::Barahlo;
use Rplus::Import::Item::VNH;

no warnings 'experimental';


sub load_item {
    my ($task) = @_;

    given($task->{media}) {
        when (/avito/) {
            Rplus::Import::Item::Avito::get_item($task->{location}, $task->{url});
        }
        when (/irr/) {
            Rplus::Import::Item::Irrru::get_item($task->{location}, $task->{url});
        }
        when (/farpost/) {
            Rplus::Import::Item::Farpost::get_item($task->{location}, $task->{url});
        }
        when (/cian/) {
            Rplus::Import::Item::CIAN::get_item($task->{location}, $task->{url});
        }
        when (/bn$/) {
            Rplus::Import::Item::BN::get_item($task->{location}, $task->{url});
        }
        when (/bnspb$/) {
            Rplus::Import::Item::BNspb::get_item($task->{location}, $task->{url});
        }
        when (/mkv/) {
            Rplus::Import::Item::MKV::get_item($task->{location}, $task->{url});
        }
        when (/present_site/) {
            Rplus::Import::Item::Present::get_item($task->{location}, $task->{url});
        }
        when (/barahlo/) {
            Rplus::Import::Item::Barahlo::get_item($task->{location}, $task->{url});
        }
        when (/vnh/) {
            Rplus::Import::Item::VNH::get_item($task->{location}, $task->{url});
        }

        default {
            say 'WTF?! dunno bout this media ' . $task->{media};
        }
    }

}

1;
