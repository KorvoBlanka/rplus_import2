package Rplus::Import::QueueDispatcher;

use Rplus::Modern;
use Rplus::Import::Queue::Avito;
use Rplus::Import::Queue::Irrru;
use Rplus::Import::Queue::Farpost;
use Rplus::Import::Queue::CIAN;
use Rplus::Import::Queue::BN;

no warnings 'experimental';


sub enqueue {
    my ($media, $location, $category) = @_;

    given($media) {
        when (/avito/) {
            Rplus::Import::Queue::Avito::enqueue_tasks($location, $category);
        }
        when (/irr/) {
            Rplus::Import::Queue::Irrru::enqueue_tasks($location, $category);
        }
        when (/farpost/) {
            Rplus::Import::Queue::Farpost::enqueue_tasks($location, $category);
        }
        when (/cian/) {
            Rplus::Import::Queue::CIAN::enqueue_tasks($location, $category);
        }
        when (/bn/) {
            Rplus::Import::Queue::BN::enqueue_tasks($location, $category);
        }

        default {
            say $media . ' WTF?!';
        }
    }

}

1;
