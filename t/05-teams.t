use warnings;
use strict;

use Data::Dumper;
use NHL::API;
use Test::More;

my $api = NHL::API->new;

my $teams = $api->teams;

print Dumper $teams;
