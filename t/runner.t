#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 16;
use Test::LectroTest;


=head1 NAME

t/005.t - tests for Property and TestRunner

=head1 SYNOPSIS

perl -Ilib t/005.t

=head1 DESCRIPTION

This test suite excercises Property and TestRunner, which work
hand in hand.

=head2 SET UP

First, we declare a few helper functions:

=cut

sub check($@) {
    my $property = shift;
    my $runner = Test::LectroTest::TestRunner->new( @_ );
    my $details = $runner->run( $property )->details;
#   print STDERR $details;
    return $details;
}

=pod

Next, we declare a few simple properties to check:

=cut

my $except_gen  = Gen { die "gen go boom!" };

my $null_1gens   = Property { ##[ ]## 1 };
my $null_2gens   = Property { ##[ ], [ ]## 1 };
my $null_retry   = Property { ##[ ]## $tcon->retry };
my $except_prop1 = Property { ##[ ]## die "prop go boom!" };
my $except_prop2 = Property { ##[ x <- $except_gen ]## 1 };
my $except_prop3 = Property { ##[ x <- Int ], [ x <- $except_gen ]## 1 };
my $ex_retry     = Property { ##[ x <- Int ], [ x <- $except_gen ]## 
                              $tcon->retry };

=pod 

=head2 TRIALS

Some tests to see if the C<trials> control knob is working.

=cut

like( check( $null_1gens, trials => 1 ),
      qr/^ok.*1 attempts/,
      "1 gen set + trials=>1 --> 1 trial" );

like( check( $null_2gens, trials => 1 ),
      qr/^ok.*2 attempts/,
      "2 gen set + trials=>1 --> 2 trials" );

=pod

=head2 RETRIES

Some tests to see if the C<retries> control knob is working.

=cut

# should not finish the first trial but abort after 10 retries

like( check( $null_retry, trials => 1, retries => 10 ),
      qr/^not ok.*incomplete/,
      "retry-always prop --> incomplete" );

# we should exhaust all of our retries on the first property check
# (using the first set of bindings) and never get to the second, which
# uses a generator that will throw an exception; therefore the
# check should be marked "incomplete"

like( check( $ex_retry, trials => 1, retries => 10 ),
      qr/^not ok.*incomplete/,
      "retry before exception prop --> incomplete" );

=pod

=head2 EXCEPTION HANDLING

Some tests to see if exceptions are caught and reported properly:

=cut

for (qw(1 2 3)) {
    my $prop_str = '$except_prop' . $_;
    my $prop = eval $prop_str or die "can't get $prop_str";
    like( check( $prop, trials => 1, retries => 10),
          qr/^not ok.*exception/s,
          "$prop_str dies and is caught" );
}

=pod

=head2 LABELING

Some tests to observe labeling properties.

=cut

like( check( ( Property { ##[ x <- Unit(0) ]##
                          $tcon->label("all"); 1 } )
           , trials => 10 )
    , qr/^ok.*100% all/s,
    , "labeling every trial --> 100%" );

like( check( ( Property { ##[ x <- Unit(0) ], [ x <- Unit(1) ]##
                          $tcon->label("odd") if $x; 1 } )
           , trials => 10 )
    , qr/^ok.*50% odd/s,
    , "labeling half of trials --> 50%" );


=pod

=head2 PRE-FLIGHT CHECKS

A few tests to see whether we are catching naughtiness
in our pre-flight checks.

=cut

eval { Property { ##[ x <- Unit(0)], [ ]##
                1 } 
};

like( $@, qr/\(\) does not match \(x\)/,
      "pre-flight: sets of bindings must have same vars (x) vs ()" );

eval { Property { ##[ x <- Unit(0)], [ y <- Unit(0) ]##
                1 } 
};

like( $@, qr/\(y\) does not match \(x\)/,
      "pre-flight: sets of bindings must have same vars (x) vs (y)" );

eval { Property { ##[ x <- Unit(0)], [ x <- Unit(0) ], [ ]##
                1 } 
};

like( $@, qr/\(\) does not match \(x\)/,
      "pre-flight: sets of bindings must have same vars (x) vs (x) vs ()" );



eval { Property { ##[ x <- Unit(0), 1 ]##
                1 } 
};

like( $@, qr/did not get a set of valid input-generator bindings/,
      "pre-flight: odd params in binding is caught" );


=pod

=head2 SCALEFN

Here we check to see whether our scaling function is being
used.

=cut

my $gen_scale = Gen { $_[0] };  # return scaling guidance as gen'd value
sub prop_scale($) {
    my $scale = shift;
    Property { ##[ x <- $gen_scale ]##
        $tcon->label("desired scale") if $x == $scale;
        1
    }
}

for (qw(0 1 10)) {
    my $scale = $_;
    like( check( prop_scale($_), scalefn => sub { $scale }, trials => 10 )
          , qr/^ok.*100% desired scale/s,
          , "desired scale $_ --> 100%" );
}


=head1 AUTHOR

Tom Moertel (tom@moertel.com)

=head1 COPYRIGHT and LICENSE

Copyright (C) 2004 by Thomas G Moertel.  All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
