package Rplus::Util::Task;

use Exporter qw(import);
use Minion;

our @EXPORT_OK = qw(add_task);

my $minion = Minion->new(Pg => 'postgresql://raven:raven!12345@localhost/rplus_import');

sub add_task {
    my ($task_name, $args, $queue) = @_;

    $minion->enqueue(
        $task_name => [$args],
        {
            #priority => 10,
            attempts => 3,
            queue => $queue,
        }
    );

    return $config;
}

1;
