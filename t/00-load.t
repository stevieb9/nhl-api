#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'NHL::API' ) || print "Bail out!\n";
}

diag( "Testing NHL::API $NHL::API::VERSION, Perl $], $^X" );
