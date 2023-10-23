use warnings;
use strict;

use Data::Dumper;
use NHL::API;
use Test::More;

my $api = NHL::API->new;

my $name = 'Toronto Maple Leafs';
is $api->team_id($name), 10, "$name has ID 10 ok";

$name = 'Edmonton Oilers';
is $api->team_id($name), 22, "$name has ID 22 ok";

done_testing();