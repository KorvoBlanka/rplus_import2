package Rplus::Class::Interface {

    use Rplus::Modern;
    use Rplus::Util::Config qw(get_config);

    my $instance;

    sub instance {
        $instance ||= (shift)->new();
    }

    sub new {
        my ($class) = @_;

        my $conf = get_config('endpoints');

        my $self = {
            endpoints => $conf->{endpoints},
            pointer => 0
        };

        bless $self, $class;

        return $self;
    }

    sub get_interface {
        my ($self) = @_;

        $self->{pointer} += 1;

        if ($self->{pointer} >= @{$self->{endpoints}}) {
            $self->{pointer} = 0;
        }

        return $self->{endpoints}->[$self->{pointer}];
    }

}

1;
