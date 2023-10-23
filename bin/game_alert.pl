use warnings;
use strict;

use Data::Dumper;
use DateTime::Format::ISO8601;
use Getopt::Long qw(:config no_ignore_case);
use IPC::Shareable;
use Net::SMTP;
use NHL::API;
use POSIX qw(strftime);

my ($help, @alert_times, @recipients, @teams);

GetOptions(
    "help|h"        => \$help,
    "alert|a=s"     => \@alert_times,
    "recipient|r=s" => \@recipients,
    "team|t=s"      => \@teams,
);

help() if ! scalar @alert_times;
help() if ! scalar @recipients;
help() if ! scalar @teams;

tie my %sent_cache, 'IPC::Shareable', {
    key => 'NHL GAME ALERTS SENT',
    create => 1
};

#_cache_flush();

my $nhl = NHL::API->new;

@alert_times = sort { $b <=> $a } @alert_times;

my $date = strftime("%Y-%m-%d", localtime);

print Dumper \@teams;
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
                    my $message = "$team is playing in less than $alert_time minutes";
                    print "$message\n";
                    for (@recipients) {
                        send_message($_, $message);
                    }
                    _cache_set($team, $date, $alert_time);
                    last;
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
sub send_message {
    my ($recipient, $message) = @_;

    my $smtp = Net::SMTP->new(
        'smtp.gmail.com',
        Hello => 'local.example.com',
        Timeout => 30,
        Debug   => 0,
        SSL     => 1,
        Port    => 465
    );

    # Password here is an app password. Need to enable 2FA on Google
    # account to generate one

    $smtp->auth($ENV{GOOGLE_API_EMAIL}, $ENV{GOOGLE_API_KEY}) or die;
    $smtp->mail($ENV{GOOGLE_API_EMAIL});
    $smtp->to($recipient);
    $smtp->data();
    $smtp->datasend($message);
    $smtp->quit();
}

sub _cache_get {
    my ($team) = @_;
    return $sent_cache{$team};
}
sub _cache_set {
    my ($team, $date, $alert_time) = @_;

    $sent_cache{$team}{$alert_time} = {
        date       => $date,
        sent       => 1
    };
}
sub _cache_reset {
    my ($team, $date, $alert_time) = @_;
    $sent_cache{$team}{$alert_time} = {
        date       => $date,
        sent       => 0
    };
}
sub _cache_flush {
    %sent_cache = ();
}

sub help {
    print <<EOF;

Usage: game_alert <OPTIONS>

Options:

-h | --help         Print this help message
-a | --alert        Mandatory, List: Minutes before game to alert at. Can be supplied multiple times
-a | --recipient    Mandatory, List: Email address to send the alert to. Can be supplied multiple times
-a | --team         Mandatory, List: Team you want to check for. Can be supplied multiple times

EOF

    exit;
}