package Rplus::Class::Media {

    use Rplus::Modern;
    use Rplus::Util::Config qw(get_config);

    my $instance;

    sub instance {
        $instance ||= (shift)->new();
    }

    sub new {
        my ($class) = @_;

        my $conf = get_config('medias');

        my $self = {
            media_list => $conf->{media_list},
        };

        bless $self, $class;

        return $self;
    }

    sub get_media {
        my ($self, $media, $location) = @_;

        return $self->{media_list}->{$media}->{$location};
    }

}

1;
