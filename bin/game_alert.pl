use warnings;
use strict;

use Data::Dumper;
use DateTime::Format::ISO8601;
use IPC::Shareable;
use NHL::API;
use POSIX qw(strftime);

tie my $sent_cache, 'IPC::Shareable', {
    key => 'NHL GAME ALERTS SENT',
    create => 1
};

#_cache_flush();

my $nhl = NHL::API->new;

my @alert_times = qw(15 60);

@alert_times = sort { $b <=> $a } @alert_times;

my $date = strftime("%Y-%m-%d", localtime);

my @teams = (
    "Toronto Maple Leafs",
    "Edmonton Oilers",
    "Buffalo Sabres",
);

#print Dumper $sent_cache;

for my $team (@teams) {

    my $game_time = $nhl->game_time($team);
    next if ! $game_time;

    my $dt_now = DateTime->now;
    my $dt_game = DateTime::Format::ISO8601->parse_datetime($game_time);

    if ($dt_game > $dt_now) {
        my $until_game_dt = $dt_game - $dt_now;
        my $minutes_to_game = $until_game_dt->in_units('minutes');

        for my $alert_time (@alert_times) {
            if ($minutes_to_game < $alert_time) {
                if (! alert_sent($team, $date, $alert_time)) {
                    print "$team is playing in $alert_time minutes\n";
                    _cache_set($team, $date, $alert_time);
                    last;
                    #print Dumper $sent_cache;
                    #_cache_reset($team, $date, $alert_time);
                    #_cache_flush();
                }
            }
        }
    }
}

sub alert_sent {
    my ($team, $date, $alert_time) = @_;

    my $team_cache = _cache_get($team);

    my $sent = 0;

    if (exists $team_cache->{$alert_time}) {
        my $alert_cache = $team_cache->{$alert_time};

        if (keys %$alert_cache && $alert_cache->{date} eq $date) {
            $sent = $alert_cache->{sent};
        }
    }

    return $sent;
}

sub _cache_get {
    my ($team) = @_;
    return $sent_cache->{$team};
}
sub _cache_set {
    my ($team, $date, $alert_time) = @_;

    $sent_cache->{$team}{$alert_time} = {
        date       => $date,
        sent       => 1
    };
}
sub _cache_reset {
    my ($team, $date, $alert_time) = @_;
    $sent_cache->{$team}{$alert_time} = {
        date       => $date,
        sent       => 0
    };
}
sub _cache_flush {
    $sent_cache = {};
}