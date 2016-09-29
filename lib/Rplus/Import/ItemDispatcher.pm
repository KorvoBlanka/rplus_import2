package Rplus::Import::ItemDispatcher;

use Rplus::Modern;
use Rplus::Import::Item::Avito;

use Data::Dumper;


sub load_item {
    my ($task) = @_;

    given($task->{media}) {
        when (/avito/) {
            Rplus::Import::Item::Avito::get_item($task->{location}, $task->{url});
        }
        when (/irrru/) {
            #Rplus::Import::Item::Avito::get_item($location, $task->{url});
        }

        default {
            say 'WTF?!';
        }
    }

}

1;
