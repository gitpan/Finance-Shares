package Finance::Shares::test;
our $VERSION = 0.01;
use strict;
use warnings;
use Log::Agent;
use Text::CSV_XS;
use Finance::Shares::Support qw(
    out show add_show_objects
);
use Finance::Shares::MySQL;
use Finance::Shares::Function;
our @ISA = 'Finance::Shares::Function';

our $MARK_START = 1;
our $MARK_SHOWN = 2;
our $MARK_HIDDEN = 3;

sub new {
    my $class = shift;
    my $o = new Finance::Shares::Function(@_);
    bless $o, $class;
   
    out($o, 4, "new $class");
    return $o;
}

sub initialize {
    my $o = shift;
    $o->{function} = 'test';
    $o->{quotes}   = $o->{fsc}->data if $o->{fsc};
}

sub build {
    my $o = shift;
    my $q = $o->{quotes};
    my $d = $q->dates;
    out($o, 5, "build test ". $o->name);
    out($o, 2, "before=", $o->{before} || 'undef');
    out($o, 2, "during=", $o->{during} || 'undef');
    out($o, 2, "after=",  $o->{after} || 'undef');

    # ensure variables are set
    my $self  = {
	first  => $q->{first},
	last   => $q->{last},
	start  => $q->{start},
	end    => $q->{end},
	by     => $q->{by},
	stock  => $q->{stock},
	date   => '0000-00-00',
	quotes => $q,
    };
    my $_l_ = $o->{line};
    my $_m_ = $o->{mark};
    my $_c_ = $o->{code};
    my $_v_  = [];
    for (my $i = 0; $i <= $#$_l_; $i++) {
	my $l = $_l_->[$i];
	my $m = $l->function;
	$_v_->[$i] = {
	    first_only => $m->{first_only},
	    state => $MARK_START,
	    next  => 0,
	    undef => 0,
	};
    }

    # before
    if ($o->{before}) {
	eval $o->{before};
	die $@ if ($@);
    }
    
    # compile code string into subroutine
    if ($o->{during}) {
	my $i;
	no warnings;
	my $sub = eval "sub { $o->{during} }";
	if ($@) {
	    $@ =~ s/\(eval \d+\) //;
	    my $err = "Code error: $@";
	    $sub = sub { die $err };
	}

	# invoke subroutine for each date
	for ($i = 0; $i <= $#$d; $i++) {
	    $self->{date} = $d->[$i];
	    eval { &$sub };
	    die $@ if ($@);
	}
    }

    # after
    if ($o->{after}) {
	eval $o->{after};
	die $@ if ($@);
    }

    # finalize
    for (my $i = 0; $i <= $#$_l_; $i++) {
	my $l = $_l_->[$i];
	my $fn = $l->function;
	$fn->finalize if $fn->{function} eq 'mark';
    }
}

sub mark {
    my ($m, $i, $d, $v) = @_;
    die "Error in mark(), syntax is 'mark(\$mark_line, <value>)'\n" unless ref($m) eq 'HASH' and ref($d) eq 'ARRAY';

    my $start = (defined $m->{state} ? ($m->{state} == $MARK_START) : 0);
    my $false = ($i - $m->{next} > $m->{undef}) || 0;
    if ($m->{first_only}) {
	if (defined $v) {
	    if ($start) {
		if ($false) {
		    $d->[$i] = $v;
		    $m->{state} = $MARK_SHOWN;
		    $m->{next} = $i+1;
		} else {
		    $m->{next} = $i+1;
		}
	    } else {
		if ($false) {
		    $d->[$i] = $v;
		    $m->{state} = $MARK_SHOWN;
		    $m->{next} = $i+1;
		} else {
		    $m->{state} = $MARK_HIDDEN;
		    $m->{next} = $i+1;
		}
	    }
	    $m->{undef} = 0;
	} else {    # $v not defined
	    if ($m->{state} == $MARK_SHOWN) {
		$m->{state} = $MARK_HIDDEN; 
	    } else {
		$m->{undef}++;
	    }
	}
    } else {
	$d->[$i] = $v;
	$m->{state} = $MARK_SHOWN;
    }
}

sub call {
    my $code = shift;
    die "Error in call(), syntax is 'call('test_tag')'\n" unless ref($code) eq 'CODE';
    return &$code(@_);
}

__END__
=head1 NAME

Finance::Shares::test - user programmable control

=head1 SYNOPSIS

Three examples of how to specify a test, one showing the minimum
required and the other illustrating all the possible fields.

    use Finance::Shares::Model;

    my @spec = (
	...
	tests => [
	    basic => qq( # perl code here ),
	    
	    iterative => {
		before => qq( # perl code here ),
		during => qq( # perl code here ),
		after  => qq( # perl code here ),
	    },
	    
	    code => sub { print "hello world\n" },
	],

	samples => [
	    ...
	    one => {
		tests => ['basic', 'iterative'],
		# NOT 'code' !
		...
	    }
	],
    );

    my $fsm = new Finance::Shares::Model( @spec );
    $fsm->build();

=head1 DESCRIPTION

This module allows model B<test> code to write points or lines on the graphs.

The code must be declared within a B<tests> block in a L<Finance::Shares::Model>
specification.  Each test is a segment of plain text containing perl code. This
is compiled by the model engine and run as required.

=head2 Test Types

As shown by the L<SYNOPSIS> examples, there are three types of test.

=head3 Simple text

The simplest and most common form, this perl fragment is run on every data
point in the sample where it is applied.  It can be used to produce conditional
signal marks on the charts, noting dates and prices for potential stock
positions either as printed output or by invoking a callback function.

=head3 Hash ref

This may have three keys, C<before>, C<during> and C<after>.  Each is a perl
fragment in text form. C<before> is run once, before the sample is considered.
C<during> is run for every point in the sample and is identical to L<Simple
text>.  C<after> is run once after C<during> has finished.

This form allows one-off invocation of callbacks, or an open-print-close
sequence for writing signals to file.  

=head3 Raw code

These are the callbacks invoked by the previous types of perl fragment.  The
parameters are those used to call the code.  See L</call> below.

=head2 Variables

In addition to perl variables declared with C<my> or C<our>, undeclared scalar
variables are used to refer to the values of other lines on the chart.

Before the code is compiled a search is made for everything that looks like
a scalar variable i.e. matches qr/\$(\w+)/.  This will be replaced with a value
if it is a tag from either B<names>, B<lines> or a fully qualified line name
(see L<Finance::Shares::Model/Fully Qualified Line Names>).  Otherwise it is
assumed to be a valid perl scalar and is left alone.

If it does refer to a line, the value becomes the value for the line at that
date.  Clearly this only makes sense while the test is iterating through the
data in the C<during> phase.

B<NOTE:> Avoid all variable names that are used by Model.  These include $open,
$high, $low, $close and $volume - aliases for the Finance::Shares::data lines.

Each test also has a special variable C<$self> available.  This is a hash ref
holding persistent values (similar to an object ref, but not blessed).
These values are predefined.

=over 8

=item $self->{date}

Only useful in the C<during> phase, this is set to the current date.

=item $self->{stock}

This is the stock code, as given to the model's B<sample> entry for this page.

=item $self->{first}

The first date which has data available.  The C<during> phase starts with this.

=item $self->{last}

The last date which has data available.  The C<during> phase ends with this.

=item $self->{start}

The first date normally displayed on the chart.

=item $self->{end}

The last date normally displayed on the chart.

=item $self->{by}

How the time periods are counted.  Will be one of quotes, weekdays, days, weeks,
months.

=item $self->{quotes}

This is the L<Finance::Shares::data> object used to store the dates, price and
volume data for the page.  See L<Finance::Shares::Model/Page Names>.

It should not normally be needed, but it provides a door into the engine for
those who need to access it.

=back

=head2 Marking the Chart

A special function is provided which will add a point to a chart line.  It is
called as

    mark( tag, value )

=over 8

=item C<tag>

This must refer to B<lines> block entry which has C<mark> as the function
field.

=item C<value>

Can be a number or undefined, but is often a psuedo-scalar variable refering to
a line.  See L</Variables> above.

=back

B<Example>

    lines => [
	circle => {
	    function => 'mark',
	},
	average => {
	    function => 'moving_average',
	},
    ],

    tests => [
	show => q(
	    mark('circle', $average);
	),
    ],

    sample => {
	test => 'show',
    },

In this example the moving average line is marked twice.  As well as the normal
line, the C<show> test is invoked and a circle (the default mark) is placed at
every position where C<average> is defined.

Notice that the engine invokes the moving average function for you as it is
referred to in the test.  There is no need to list it explicitly as a line.
    
=head2 Calling Foreign Code

Model B<test> entries may be code refs as well as text.  The code is then called
using a special function.

    call( tag, arguments )

=over 8

=item C<tag>

This must be a tag in a B<tests> block identifying a code ref.

=item C<arguments>

This list of arguments (or none) is passed to the subroutine identified by
C<tag>.

=back

B<Example>

    tests => [
	tcode => {
	    my $v = shift;
	    print "$v->{stock} quotes from $v->{first}\n";
	},
	doit => {
	    before => q(
		call('tcode', $self);
	    ),
	},
    ],

    sample => {
	test => 'doit',
    },

Remember that C<$self> has a number of predefined fields, C<{stock}> and
C<{first}> among them.  The C<before> code is only invoked at the start of the
test.  It calls the subroutine which prints a message.

This might seem an involved way to go about it, but it is extremely powerful.
The subroutine call is made within code which has all the model values (as well
as the complete power of perl) available.  It may be passed whatever values you
choose.

B<Example>

This is a slightly more useful example.  It assumes that the MyPortfolio module
has exported subroutines defined for simulating buying/selling shares and
keeping track of positions you hold in the market.  A 'buy' call is made when
the stock price seems to rise.

    # declare function modules used
    use Finance::Shares::moving_average;
    
    # import callback from another module
    use MyPortFolio 'enter_long_position';

    # Model specification begins
    ...
    
    lines => [
	fast => {
	    function => 'moving_average',
	    period   => 5,
	},
	slow => {
	    function => 'moving_average',
	    period   => 20,
	},
    ],

    tests => [
	buy  => &enter_long_position,
	code => q(
	    call('buy', 'pf1', $self->{date}, $low, $high)
		    if $fast >= $slow;
	);
    ],

    sample => {
	test => 'code',
    },

When the 5 day moving average crosses above the 20 day one, the callback is
invoked.  It will be passed a portfolio ID, the date, lowest and highest proces
for the day.

<realism> A buy signal would need to be invoked on the basis if at least
yesterday's data as todays is usually not yet known!  This might be done by
using a $self->{buy} flag and having C<after =E<gt> 1> set in the appropriate
B<dates> entry. </realism>

=head1 BUGS

Please let me know when you suspect something isn't right.  A short script
working from a CSV file demonstrating the problem would be very helpful.

=head1 AUTHOR

Chris Willmot, chris@willmot.org.uk

=head1 LICENCE

Copyright (c) 2002-2003 Christopher P Willmot

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
A copy can be found at L<http://www.gnu.org/copyleft/gpl.html>

=head1 SEE ALSO

L<Finance::Shares::Overview> provides an introduction to the suite, and
L<fsmodel> is the principal script.

Modules involved in processing the model include L<Finance::Shares::Model>,
L<Finance::Shares::MySQL>, L<Finance::Shares::Chart>.
Chart and file details may be found in L<PostScript::File>,
L<PostScript::Graph::Paper>, L<PostScript::Graph::Key>,
L<PostScript::Graph::Style>.

All functions are invoked from their own modules, all with lower-case names such
as L<Finance::Shares::moving_average>.  The nitty-gritty on how to write each
line specification are found there.

The quote data is stored in a L<Finance::Shares::data> object.
For information on writing additional line functions see
L<Finance::Share::Function> and L<Finance::Share::Line>.
Also, L<Finance::Share::test> covers writing your own tests.

=cut

