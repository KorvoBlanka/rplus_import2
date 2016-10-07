package Rplus::Import::ItemDispatcher;

use Rplus::Modern;
use Rplus::Import::Item::Avito;
use Rplus::Import::Item::Irrru;
use Rplus::Import::Item::Farpost;
use Rplus::Import::Item::CIAN;

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

        default {
            say 'WTF?! dunno bout this media ' . $task->{media};
        }
    }

}

1;
