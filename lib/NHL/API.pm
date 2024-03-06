package NHL::API;

use strict;
use warnings;

use Carp qw(croak);
use Data::Dumper;
use DateTime;
use DateTime::Format::ISO8601;
use File::HomeDir;
use HTTP::Request;
use JSON;
use LWP::UserAgent;
use POSIX qw(strftime);

our $VERSION = '0.01';

my $home_dir;

BEGIN {
    $home_dir = File::HomeDir->my_home;
}

my $ua = LWP::UserAgent->new(
    agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15"
);
my $url = 'https://api-web.nhle.com/';
my $alt_url = 'https://api.nhle.com/';

sub new {
    my ($class, %args) = @_;

    my $self = bless {}, $class;

    $self->_args(\%args);

    return $self;
}
sub fetch {
    my ($self, $want_uri, $base_url) = @_;

    if (! $want_uri) {
        croak "fetch() requires a REST path...";
    }

    $base_url //= $url;

    my ($req, $response);

    $req = HTTP::Request->new('GET', $self->_uri($want_uri, $base_url));
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

    return $self->{teams} if exists $self->{teams};

    my $team_data = $self->fetch("stats/rest/en/team", $alt_url)->{data};

    for (@$team_data) {
        $self->{teams}{$_->{fullName}} = {
            id   => $_->{id},
            abbr => $_->{triCode},
        };
    }

    return $self->{teams};
}
sub game_location {
    my ($self, $team_name) = @_;

    my $game_data = $self->_today_game($team_name);
    my $game_location = $game_data->{homeTeam}{placeName}{default};
    return $game_location;
}
sub opponent {
    my ($self, $team_name) = @_;

    my $game_data = $self->_today_game($team_name);
    my $opponent_abbr;

    if ($game_data) {
        my $team_abbr = $self->team_abbr($team_name);

        if ($game_data->{homeTeam}{abbrev} ne $team_abbr) {
            $opponent_abbr = $game_data->{homeTeam}{abbrev};
        }
        else {
            $opponent_abbr = $game_data->{awayTeam}{abbrev};
        }
    }

    return $self->team_abbr_to_name($opponent_abbr);
}
sub team_abbr_to_name {
    my ($self, $abbr) = @_;

    my $teams = $self->teams;

    if (! exists $self->{abbrs}) {
        for (keys %$teams) {
            $self->{abbrs}{$teams->{$_}{abbr}} = $_;
        }
    }

    return $self->{abbrs}{$abbr};
}
sub team_abbr {
    my ($self, $team_name) = @_;

    if (! $team_name) {
        croak "team_abbr() requires a Team Name sent in...";
    }

    my $teams = $self->teams;

    return $teams->{$team_name}{abbr};
}
sub game_time {
    my ($self, $team_name) = @_;

    my $today_game = $self->_today_game($team_name);

    if ($today_game) {
        return $today_game->{startTimeUTC};
    }

    return undef;
}
sub _today_game {
    my ($self, $team_name) = @_;

    my $date = strftime("%Y-%m-%d", localtime);

    my $team_abbr = $self->team_abbr($team_name);
    my $games = $self->fetch("v1/club-schedule/$team_abbr/week/now")->{games};

    for (@$games) {
        if ($_->{gameDate} eq $date) {
            return $_;
        }
    }
    return undef;
}
sub _args {

}
sub _uri {
    my ($self, $want_uri, $base_url) = @_;
    my $uri = $base_url . $want_uri;
    return $uri;
}

sub __placeholder {}

1;