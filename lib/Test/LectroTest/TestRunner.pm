package Test::LectroTest::TestRunner;

use strict;
use warnings;

use Carp;
use Data::Dumper;

use Test::LectroTest::Property qw( NO_FILTER );

=head1 NAME

Test::LectroTest::TestRunner - Configurable Test::Harness-compatible engine for running LectroTest property checks

=head1 SYNOPSIS

 use Test::LectroTest::TestRunner;

 my @args = trials => 1_000, retries => 20_000;
 my $runner = Test::LectroTest::TestRunner->new( @args );

 # test a single property and print details upon failure
 my $result = $runner->run( $a_single_lectrotest_property );
 print $result->details unless $result->success;

 # test a suite of properties, w/ Test::Harness output
 my $all_successful = $runner->run_suite( @properties );
 print "Splendid!" if $all_successful;

=head1 DESCRIPTION

B<STOP!> If you just want to write and run simple tests, see
L<Test::LectroTest>.  If you really want to learn about or turn the
control knobs of the property-checking apparatus, read on.

This module provides Test::LectroTest::TestRunner, a class of objects
that tests properties by running repeated random trials.  You create a
TestRunner, configure it, and then call its C<run> or C<run_suite>
methods to test properties individually or in groups.

=head1 METHODS

The following methods are available.

=cut

our %defaults = ( trials  =>  1_000,
                  retries => 20_000,
                  scalefn => sub { $_[0] / 2 + 1 },
                  number  => 1,
                  verbose => 1
);

# build field accessors

for my $field (keys %defaults) {
    no strict 'refs';
    *{$field} = sub {
        my $self = shift;
        $self->{$field} = $_[0] if @_;
        $self->{$field}
    };
}


=pod

=head2 new(I<named-params>)

  my $runner = new Test::LectroTest::TestRunner(
    trials  => 1_000,
    retries => 20_000,
    scalefn => sub { $_[0] / 2 + 1 },
    verbose => 1
  );

Creates a new Test::LectroTest::TestRunner and configures it with the
given named parameters, if any.  Typically, you need only provide the
C<trials> parameter because the other values are reasonable for almost
all situations.  Here is what each parameter means:

=over 4

=item trials

The number of trials to run against each property checked.
The default is 1_000.

=item retries

The number of times to allow a property to retry trials (via
C<$tcon-E<gt>retry>) during the entire property check before aborting
the check.  This is used to prevent infinite looping, should
the property retry every attempt.

=item scalefn

A subroutine that scales the sizing guidance given to input
generators.

The TestRunner starts with an initial guidance of 1 at the beginning
of a property check.  For each trial (or retry) of the property, the
guidance value is incremented.  This causes successive trials to be
tried using successively more complex inputs.  The C<scalefn>
subroutine gets to adjust this guidance on the way to the input
generators.  Typically, you would change the C<scalefn> subroutine if
you wanted to change the rate and which inputs grow during the course
of the trials.

=item verbose

If true (the default) the TestRunner will use verbose output that
includes things like label frequencies and counterexamples.  Otherwise,
only one-line summaries will be output.  Unless you have a good
reason to do otherwise, leave this parameter alone because verbose
output is almost always what you want.

=back

You can also set and get the values of the configuration properties
using accessors of the same name.  For example:

  $runner->trials( 10_000 );

=cut

sub new { 
    my $self = shift;
    my $class = ref($self) || $self;
    return bless { %defaults, @_ }, $class; 
}

=pod

=head2 run(I<property>)

  $results = $runner->run( $a_property );
  print $results->summary, "\n";
  if ($results->success) {
      # celebrate!
  }

Checks whether the given property holds by running repeated random
trials.  The result is a Test::LectroTest::TestRunner::results object,
which you can query for fined-grained information about the outcome of
the check.

The C<run> method takes an optional second argument which gives
the test number.  If it is not provided (usually the case), the
next number available from the TestRunner's internal counter is
used.

  $results = $runner->run( $third_property, 3 );

=cut

sub run {
    my ($self, $test, $number) = @_;

    # if a test number wasn't provided, take the next from our counter

    unless (defined $number) {
        $number = $self->number;
        $self->number( $number + 1);
    }

    # create a new results object to hold our results; run trials

    my ($inputs_list, $testfn, $name) = @$test{qw/inputs test name/};
    my $results = Test::LectroTest::TestRunner::results->new(
        name => $name, number => $number
    );

    # create an empty label store and start at attempts = 0

    my %labels;
    my $attempts = 0;

    # for each set of input-generators, run a series of trials

    for my $gen_specs (@$inputs_list) {

        my $retries = 0;
        my $base_size = 0;
        my @vars = sort keys %$gen_specs;
        my $scalefn = $self->scalefn;

        for (1 .. $self->trials) {

            # run a trial

            $base_size++;
            my $controller=Test::LectroTest::TestRunner::testcontroller->new();
            my $size = $scalefn->($base_size);
            my $inputs = { "WARNING" => "EXCEPTION FROM WITHIN GENERATOR" };
            my $success = eval {
                $inputs = { map {($_, $gen_specs->{$_}->generate($size))}
                            @vars };
                $testfn->($controller, @$inputs{@vars});
            }; 

            # did the trial bail out owing to an exception?

            $results->exception( do { my $ex=$@; chomp $ex; $ex } ) if $@;

            # was it retried?

            if ($controller->retried) {
                $retries++;
                if ($retries >= $self->retries) {
                    $results->incomplete("$retries retries exceeded");
                    $results->attempts( $attempts );
                    return $results;
                }
                redo;  # re-run the trial w/ new inputs
            }

            # the trial ran to completation, so count the attempt

            $attempts++;

            # and count the trial toward the bin with matching labels

            if ($controller->labels) {
                local $" = " & ";
                my @cl = sort @{$controller->labels};
                $labels{"@cl"}++ if @cl;
            }

            # if the trial outcome was failure, return a counterexample

            unless ( $success ) {
                $results->counterexample_( $inputs );
                $results->attempts( $attempts );
                return $results;
            }

            # otherwise, loop up to the next trial
        }
    }
    $results->success(1);
    $results->attempts( $attempts );
    $results->labels( \%labels );
    return $results;
}

=pod

=head2 run_suite(I<properties>...)

  my $all_success = $runner->run_suite( @properties );
  if ($all_success) {
      # celebrate most jubilantly!
  }

Checks a suite of properties, sending the results of each
property checked to C<STDOUT> in a form that is compatible with
L<Test::Harness>.  For example:

  1..5
  ok 1 - Property->new disallows use of 'tcon' in bindings
  ok 2 - magic Property syntax disallows use of 'tcon' in bindings
  ok 3 - exceptions are caught and reported as failures
  ok 4 - pre-flight check catches new w/ no args
  ok 5 - pre-flight check catches unbalanced arguments list

By default, labeling statistics and counterexamples (if any) are
included in the output if the TestRunner's C<verbose> property is
true.  You may override the default by passing the C<verbose> named
parameter after all of the properties in the argument list:

  my $all_success = $runner->run_suite( @properties,
                                        verbose => 1 );

=cut

sub run_suite {
    local $| = 1;
    my $self = shift;
    my @tests;
    my @opts;
    while (@_) {
        if (ref $_[0]) {  push @tests, shift;       }
        else           {  push @opts, shift, shift; }
    }
    my %opts = (verbose => $self->verbose, @opts);
    my $verbose = $opts{verbose};
    $self->number(1);  # reset test-number count
    my $success = 1;   # assume success
    print "1..", scalar @tests, "\n";
    for (@tests) {
        my $results = $self->run($_);
        print $verbose ? $results->details : $results->summary ."\n";
        $success &&= $results->success;
    }
    return $success;
}

=pod

=head1 HELPER OBJECTS

There are two kinds of objects that TestRunner uses as helpers.
Neither is meant to be created by you.  Rather, a TestRunner
will create them on your behalf when they are needed.

The objects are described in the following subsections.


=head2 Test::LectroTest::TestRunner::results

  my $results = $runner->run( $a_property );
  print "Property name: ", $results->name, ": ";
  print $results->success ? "Winner!" : "Loser!";

This is the object that you get back from C<run>.  It contains all of
the information available about the outcome of a property check
and provides the following methods:

=over 4

=item success

Boolean value:  True if the property checked out successfully;
false otherwise.

=item summary

Returns a one line summary of the property-check outcome.  It does not
end with a newline.  Example:

  ok 1 - Property->new disallows use of 'tcon' in bindings

=item details

Returns all relevant information about the property-check outcome as a
series of lines.  The last line is terminated with a newline.  The
details are identical to the summary (except for the terminating
newline) unless label frequencies are present or a counterexample is
present, in which case the details will have these extras (the
summary does not).  Example:

  1..1
  not ok 1 - 'my_sqrt meets defn of sqrt' falsified in 1 attempts
  # Counterexample:
  # $x = '0.546384454460178';

=item name

Returns the name of the property to which the results pertain.

=item number

The number assigned to the property that was checked.

=item counterexample

Returns the counterexample that "broke" the code being tested, if
there is one.  Otherwise, returns an empty string.

=item labels

Label counts.  If any labels were applied to trails during the
property check, this value will be a reference to a hash mapping each
combination of labels to the count of trials that had that particular
combination.  Otherwise, it will be undefined.

Note that each trial is counted only once -- for the I<most-specific>
combination of labels that were applied to it.  For example, consider
the following labeling logic:

  Property {
    ##[ x <- Int ]##
    $tcon->label("negative") if $x < 0;
    $tcon->label("odd")      if $x % 2;
    1;
  }, name => "negative/odd";

For a particular trial, if I<x> was 2 (positive and even), the trial
would receive no labels.  If I<x> was 3 (positive and odd), the trial
would be labeled "odd".  If I<x> was -2 (negative and even), the trial
would be labeled "negative".  If I<x> was -3 (negative and odd), the
trial would be labeled "negative & odd".

=item label_frequencies

Returns a string containing a line-by-line accounting of labels
applied during the series of trials:

  print $results->label_frequencies;

The corresponding output looks like this:

  25% negative
  25% negative & odd
  25% odd

If no labels were applied, an empty string is returned.  

=item exception

Returns the text of the exception or error that caused the series of
trials to be aborted, if the trials were aborted because an exception
or error was intercepted by LectroTest.  Otherwise, returns an empty
string.

=item attempts

Returns the count of trials performed.

=item incomplete

In the event that the series of trials was halted before it was
completed (such as when the retry count was exhausted), this method will
return the reason.  Otherwise, it returns an empty string.

Note that a series of trials I<is> complete if a counterexample was
found.

=back

=cut

package Test::LectroTest::TestRunner::results;
use Class::Struct;
import Data::Dumper;

struct( name            => '$',
        success         => '$',
        labels          => '$',
        counterexample_ => '$',
        exception       => '$',
        attempts        => '$',
        incomplete      => '$',
        number          => '$',
);

sub summary {
    my $self = shift;
    my ($name, $attempts) = ($self->name, $self->attempts);
    my $incomplete = $self->incomplete;
    my $number = $self->number || 1;
    local $" = " / ";
    return $self->success
        ? "ok $number - '$name' ($attempts attempts)"
        : $incomplete
            ? "not ok $number - '$name' incomplete ($incomplete)"
            : "not ok $number - '$name' falsified in $attempts attempts";
}

sub details {
    my $self = shift;
    my $summary = $self->summary . "\n";
    my $details .= $self->label_frequencies;
    my $cx = $self->counterexample;
    if ( $cx ) {
        $details .= "Counterexample:\n$cx";
    }
    my $ex = $self->exception;
    if ( $ex ) {
        local $Data::Dumper::Terse = 1;
        $details .= "Caught exception: " . Dumper($ex);
    }
    $details =~ s/^/\# /mg if $details;  # mark as Test::Harness comments
    return "$summary$details";
}

sub label_frequencies {
    my $self = shift;
    my $l = $self->labels || {} ;
    my $total = $self->attempts;
    my @keys = sort { $l->{$b} <=> $l->{$a} } keys %$l;
    join( "\n",
          (map {sprintf "% 3d%% %s", (200*$l->{$_}+1)/(2*$total), $_} @keys),
          ""
    );
}

sub counterexample {
    my $self = shift;
    my $vars = $self->counterexample_;
    return "" unless $vars;  # no counterexample
    my $sorted_keys = [ sort keys %$vars ];
    my $dd = Data::Dumper->new([@$vars{@$sorted_keys}], $sorted_keys);
    $dd->Sortkeys(1) if $dd->can("Sortkeys");
    return $dd->Dump;
}

=pod 

=head2 Test::LectroTest::TestRunner::testcontroller

During a live property-check trial, the variable C<$tcon> is
available to your Properties.  It lets you label the current
trial or request that it be re-tried with new inputs.

The following methods are available.

=cut

package Test::LectroTest::TestRunner::testcontroller;
import Class::Struct;

struct ( labels => '$', retried => '$' );

=pod

=over 4

=item retry

    Property {
      ##[ x <- Int ]##
      return $tcon->retry if $x == 0; 
    }, ... ;


Stops the current trial and tells the TestRunner to re-try it
with new inputs.  Typically used to reject a particular case
of inputs that doesn't make for a good or valid test.

=cut

sub retry {
    shift->retried(1);
}


=pod

=item label

    Property {
      ##[ x <- Int ]##
      $tcon->label("negative") if $x < 0; 
      $tcon->label("odd")      if $x % 2; 
    }, ... ;

Applies a label to the current trial.  At the end of the trial, all of
the labels are gathered together, and the trial is dropped into a
bucket bearing the combined label.  See the discussion of
L</labels> for more.

=cut


sub label {
    my $self = shift;
    my $labels = $self->labels || [];
    push @$labels, @_;
    $self->labels( $labels );
}

=pod

=item trivial

    Property {
      ##[ x <- Int ]##
      $tcon->trivial if $x == 0; 
    }, ... ;

Applies the label "trivial" to the current trial.  It is identical to
calling C<label> with "trivial" as the argument.

=cut 

sub trivial {
    shift->label("trivial");
}

=pod

=back

=cut

package Test::LectroTest::TestRunner;

1;

=head1 SEE ALSO

L<Test::LectroTest::Property> explains in detail what
you can put inside of your property specifications.

=head1 LECTROTEST HOME

The LectroTest home is 
http://community.moertel.com/LectroTest.
There you will find more documentation, presentations, a wiki,
and other helpful LectroTest-related resources.  It's also the
best place to ask questions.

=head1 AUTHOR

Tom Moertel (tom@moertel.com)

=head1 INSPIRATION

The LectroTest project was inspired by Haskell's fabulous
QuickCheck module by Koen Claessen and John Hughes:
http://www.cs.chalmers.se/~rjmh/QuickCheck/.

=head1 COPYRIGHT and LICENSE

Copyright (c) 2004-05 by Thomas G Moertel.  All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
