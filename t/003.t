#!/usr/bin/perl

use warnings;
use strict;

use Test::LectroTest::Property;
use Test::LectroTest::TestRunner;
use Test::More tests => 10;

=head1 NAME

t/003.t - Error-handling tests

=head1 SYNOPSIS

    perl -Ilib t/003.t

=head1 DESCRIPTION

First, we see whether LectroTest::Property prevents you from
using the reserved identifier "tcon" in a generator-binding
declaration.

=cut

eval { 
    Property { [ tcon => 1 ] } sub {
        1;
    }
};
like($@, qr/cannot use reserved name 'tcon' in a generator binding/,
   "Property->new disallows use of 'tcon' in bindings");

eval { 
    Property { ##[ tcon <- 1 ]##
        1;
    }
};
like($@, qr/cannot use reserved name 'tcon' in a generator binding/,
   "magic Property syntax disallows use of 'tcon' in bindings");


=pod

Second, we see whether exceptions throw (e.g., via die) during
testing are caught and reported.

=cut

my $will_throw = Property {
    ##[ ]##
    die "test threw exception";
};

sub run_details($);
like( run_details($will_throw), qr/test threw exception/, 
      "exceptions are caught and reported as failures" );


=pod

Third, we check to see if C<new> catches and complains
about bad arguments in its pre-flight checks:

=cut

eval {
    Test::LectroTest::Property->new();
};
like( $@, qr/test subroutine must be provided/,
      "pre-flight check catches new w/ no args" );


eval {
    Test::LectroTest::Property->new('inputs');
};
like( $@, qr/invalid list of named parameters/,
      "pre-flight check catches unbalanced arguments list" );


eval {
    Test::LectroTest::Property->new(inputs=>[]);
};
like( $@, qr/test subroutine must be provided/,
      "pre-flight check catches new w/o test sub" );

=pod

Fourth, we make sure that the we report as incomplete those
tests that don't meet the requested number of trials because
they exceeded their retry limit:

=cut

my $will_be_incomplete = Property { ##[ ]##
    return $tcon->retry;
    1;  # never get here
};

like( run_details( $will_be_incomplete ), qr/not ok .* incomplete/,
      "incomplete tests reported as such" );

=pod

Fifth, we make sure that labeling statistics are captured
and reported accurately.

=cut

sub labler {
    my @labels = @_;
    my $count = 0;
    return Property {
        ##[ ]##
        $tcon->label( $labels[$count++] );
        $count = 0 if $count == @labels;
        1;
    };
}

like( run_details(labler(qw|a a a b|)),
      qr/ 75% a.*25% b/s,
      "75/25 labeling case checks" );

like( run_details(labler(qw|a a a a a a a b b c|)),
      qr/ 70% a.*20% b.*10% c/s,
      "70/20/10 labeling case checks" );


my $trivial = Property { ##[ #]##
    $tcon->trivial;
    1;
};

like( run_details($trivial),
      qr/100% trivial/,
      "100% trivial labeling case checks" );


=head1 HELPERS

The C<run_details> helper runs a check of the given
property and returns the C<details> of the results.

=cut

sub run_details($) {
    my $runner = new Test::LectroTest::TestRunner;
    return $runner->run(@_)->details;
}


=head1 AUTHOR

Tom Moertel (tom@moertel.com)

=head1 COPYRIGHT and LICENSE

Copyright (C) 2004 by Thomas G Moertel.  All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
