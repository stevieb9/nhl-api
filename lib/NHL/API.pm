package NHL::API;

use strict;
use warnings;

use Carp qw(croak);
use Data::Dumper;
use DateTime;
use DateTime::Format::ISO8601;
use HTTP::Request;
use JSON;
use LWP::UserAgent;

our $VERSION = '0.01';

my $ua = LWP::UserAgent->new;
my $url = 'https://statsapi.web.nhl.com/api/v1/';

sub new {
    my ($class, %args) = @_;

    my $self = bless {}, $class;

    $self->_args(\%args);

    return $self;
}
sub fetch {
    my ($self, $want_uri, $params) = @_;

    if (! $want_uri) {
        croak "fetch() requires a valid category...";
    }

    my ($req, $response);

    $req = HTTP::Request->new('GET', $self->_uri($want_uri, $params));
    $response = $ua->request($req);

    if ($response->is_success) {
        my $json;

        $json = $response->decoded_content;
        my $result = decode_json $json;

        return $result;
    }
    else {
        print "Invalid response\n\n";
        return undef;
    }
}
sub teams {
    my ($self) = @_;

    my $data = $self->fetch('teams');

    return $data->{teams};
}
sub team_id {
    my ($self, $team_name) = @_;

    if (! $team_name) {
        croak "team_id() requires a Team Name sent in...";
    }

    my $teams = $self->teams;

    my $team_id;

    for my $team (@$teams) {
        if ($team->{name} eq $team_name) {
            $team_id = $team->{id};
            last;
        }
    }

    return $team_id;
}
sub game_time {
    my ($self, $team_name) = @_;

    my $team_id = $self->team_id($team_name);

    my $games = $self->fetch('schedule')->{dates}[0]{games};

    my $game_time;

    for my $game (@$games) {
        my $home_team_id = $game->{teams}{home}{team}{id};
        my $away_team_id = $game->{teams}{away}{team}{id};

        if ($home_team_id == $team_id || $away_team_id == $team_id) {
           $game_time = $game->{gameDate};
        }
    }

    if ($game_time) {
        my $dt = DateTime::Format::ISO8601->parse_datetime($game_time);
        $dt->set_time_zone('America/Vancouver');
    }

    return $game_time;
}

sub _args {

}
sub _uri {
    my ($self, $want_uri) = @_;

    my %uris = (
        schedule => 'schedule',
        teams    => 'teams',
        team_id  => 'team_id',
    );

    if (! exists $uris{$want_uri}) {
        croak "'$want_uri' isn't a valid URI category...";
    }

    my $uri = $url . $uris{$want_uri};

    return $uri;
}

sub __placeholder {}

1;