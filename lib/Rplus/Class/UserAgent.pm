package Rplus::Class::UserAgent {

    use Rplus::Modern;
    use Mojo::UserAgent;

    use Data::Dumper;

    sub new {
        my ($class, $interface) = @_;

        say 'using if: ' . $interface;

        my $ua = Mojo::UserAgent->new;
        $ua->max_redirects(4);
        $ua->local_address($interface);

        my $self = {
          name => 'UserAgentWrapper',
          ua => $ua
        };

        bless $self, $class;

        return $self;
    }

    sub get_res {
        my ($self, $url, $headers) = @_;

        my $res;
        my $retry = 3;

        while ($retry > 0) {
            $retry -= 1;

            my $t = $self->{ua}->get($url, {
                @{$headers},
                'Connection' => 'keep-alive',
                'Cache-Control' => 'max-age=0',
                'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.1916.114 Safari/537.36',
                'Accept-Encoding' => 'gzip,deflate,sdch',
                'Accept-Language' => 'ru-RU,ru;q=0.8,en-US;q=0.6,en;q=0.4',
            });

            if ($t->res->code == 200) {
                $res = $t->res;
                last;
            } elsif ($t->res->code == 404) {
                last;
            }

            sleep 3;
        }

        return $res;
    }

}

1;
