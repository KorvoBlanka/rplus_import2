package Rplus::Class::Interface {

    use String::Urandom;
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
        };

        bless $self, $class;

        return $self;
    }

    sub get_interface {
        my ($self) = @_;

        #if ($self->{pointer} >= @{$self->{endpoints}}) {
        #}

        my $obj = String::Urandom->new(
              LENGTH => 3,
              CHARS  => [ qw/ 1 2 3 4 5 6 7 8 9 0 / ]
            );

        my $sz = scalar @{$self->{endpoints}};
        my $idx = int(($obj->rand_string / 999) * ($sz));
        say 'rand idx: ' . $idx;

        return $self->{endpoints}->[$idx];
    }
}

1;
