package Rplus::Import::QueueDispatcher;

use Rplus::Modern;
use Rplus::Import::Queue::Avito;
use Rplus::Import::Queue::Irrru;
use Rplus::Import::Queue::Farpost;
use Rplus::Import::Queue::CIAN;
use Rplus::Import::Queue::BN;
use Rplus::Import::Queue::BNspb;
use Rplus::Import::Queue::MKV;
use Rplus::Import::Queue::Present;
use Rplus::Import::Queue::Barahlo;
use Rplus::Import::Queue::VNH;

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
        when (/bn$/) {
            Rplus::Import::Queue::BN::enqueue_tasks($location, $category);
        }
        when (/bnspb$/) {
            Rplus::Import::Queue::BNspb::enqueue_tasks($location, $category);
        }
        when (/mkv/) {
            Rplus::Import::Queue::MKV::enqueue_tasks($location, $category);
        }
        when (/present_site/) {
            Rplus::Import::Queue::Present::enqueue_tasks($location, $category);
        }
        when (/barahlo/) {
            Rplus::Import::Queue::Barahlo::enqueue_tasks($location, $category);
        }
        when (/vnh/) {
            Rplus::Import::Queue::VNH::enqueue_tasks($location, $category);
        }

        default {
            say $media . ' WTF?!';
        }
    }

}

1;
