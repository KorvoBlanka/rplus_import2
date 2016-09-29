package RplusImport2::Controller::API::Result;
use Mojo::Base 'Mojolicious::Controller';

use Rplus::Model::Result::Manager;

# This action will render a template
sub get {
    my $self = shift;

    my $media = $self->param('media');
    my $location = $self->param('location');

    return $self->render(json => {error => 'Bad Request'}, status => 400) unless $media;
    return $self->render(json => {error => 'Bad Request'}, status => 400) unless $location;

    my $list = {
        list => [],
        count => 0,
    };

    my $iter = Rplus::Model::Result::Manager->get_objects_iterator(query => [
        media => $media,
        location => $location
    ]);

    while(my $result = $iter->next) {
        my $r = {
            data => $result->metadata
        };
        $list->{count} += 1;
        push @{$list->{list}}, $r;
    }

    $self->render(json => $list);
}

1;
