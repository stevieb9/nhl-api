use warnings;
use strict;

use Data::Dumper;
use NHL::API;
use Test::More;

my $api = NHL::API->new;

my $name = 'Buffalo Sabres';

my $next_game = $api->game_time($name);

print Dumper $next_game;
