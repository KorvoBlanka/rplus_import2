package Rplus::Import::QueueDispatcher;

use Rplus::Modern;
use Rplus::Import::Queue::Avito;

sub enqueue {
    my ($media, $location, $category) = @_;

    say $media;
    say $location;
    say $category;
    say '2';

    given($media) {
        when (/avito/) {
            Rplus::Import::Queue::Avito::enqueue_tasks($location, $category);
        }
        when (/irrru/) {
            #Rplus::Import::Queue::Irrru::enqueue_tasks($location);
        }
    }

}

1;
