#!/usr/bin/perl -w

use strict;
use Test::LectroTest::Compat tests => 5;
use Test::More;

my $true = Property {
    ##[ ]##
    1
}, name => "always succeeds";

my $false = Property {
    ##[  ]##
    0
}, name => "always fails";


my $cmp_ok = Property {
    ##[ x <- Int( range=>[0,10] ) ]##
    cmp_ok($x, '>=', 0) && cmp_ok($x, '<=', 10);
}, name => "cmp_ok can be used";

my $cmp_ok_fail = Property {
    ##[ x <- Int( range=>[0,10] ) ]##
    cmp_ok($x, '>', 0) && cmp_ok($x, '<=', 10);
}, name => "cmp_ok can be used (2)";;


holds( $true, trials => 5 );
# holds( $false );
holds( $cmp_ok );
holds( $cmp_ok_fail );

cmp_ok( 0, '<', 1, "trivial 0<1 test" );

holds( Property {
    ##[ ]##
    1;
}, name => "inline" );


cmp_ok( 0, '<', 1, "trivial 0<1 test" );
