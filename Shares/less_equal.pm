package Finance::Shares::less_equal;
our $VERSION = 1.03;
use strict;
use warnings;
use Log::Agent;
use Finance::Shares::Function;
use Finance::Shares::Support qw(out show);
our @ISA = 'Finance::Shares::Function';

sub new {
    my $class = shift;
    my $o = new Finance::Shares::Function(@_);
    bless $o, $class;
}

sub initialize {
    my $o = shift;

    $o->common_defaults('logic', 'close', 'open');
    $o->level_defaults;

    $o->add_line('line', 
	    gtype  => $o->{gtype},
	    graph  => $o->{graph},

	    key    => $o->{key} || '',
	    style  => $o->{style},
	    shown  => $o->{shown},
	    order  => $o->{order},

	    max    => $o->{max},
	    min    => $o->{min},
	    decay  => $o->{decay},
	    ramp   => $o->{ramp},
	    scale  => 1,
	);
}

sub build {
    my $o = shift;
    my $q = $o->{quotes};
    my $d = $q->dates;
    my $l = $o->func_line('line');

    my $first = $o->{line}[0][0];
    my $second = $o->{line}[1][0];
    my $d1 = $first->{data};
    my $d2 = $second->{data};
    $l->{key} = "'$first->{key}' <= '$second->{key}'" unless $l->{key};
    
    my ($prev, $plevel, $level);
    my @points;
    for (my $i = 0; $i <= $#$d; $i++) {
	my $v1 = $d1->[$i];
	my $v2 = $d2->[$i];
	
	if (defined $v1 and defined $v2) {
	    my $value = ($v1 <= $v2);
	    if (defined $prev) {
		if ($value == $prev) {
		    $level = $l->condition_level($plevel);
		    $level = $l->{lmin} if $level < $l->{lmin};
		    $level = $l->{lmax} if $level > $l->{lmax};
		} else {
		    $level = $value ? $l->{lmax} : $l->{lmin};
		}
	    } else {
		$level = $value ? $l->{lmax} : $l->{lmin};
	    }
	    $prev = $value;
	    push @points, $level;
	    $plevel = $level;
	} else {
	    push @points, undef;
	}
    }
    $l->{data} = \@points;
}

__END__
=head1 NAME

Finance::Shares::less_equal - Compare two lines, value by value

=head1 SYNOPSIS

Two examples of how to specify a comparison line, one showing the minimum
required and the other illustrating all the possible fields.

    use Finance::Shares::Model;
    use Finance::Shares::less_equal;

    my @spec = (
	...
	lines => [
	    ...
	    minimal => {
		function => 'less_equal',
		lines    => ['line1', 'line2'],
	    },
	    full = {
		function => 'less_equal',
		graph    => 'Stock Prices',
		gtype    => 'price',
		lines    => ['line1', 'line2'],
		key      => 'line 1 > line 2',
		style    => { ... },
		shown    => 1,
		order    => -99,
		min      => 300,
		max      => 400,
		decay    => 0.9,
		ramp     => -10,
	    },
	    ...
	],

	samples => [
	    ...
	    one => {
		lines => ['full', 'minimal'],
		...
	    }
	],
    );

    my $fsm = new Finance::Shares::Model( @spec );
    $fsm->build();

=head1 DESCRIPTION

=head2 This module is depreciated

Use test code instead.  The following example highlights price lows where the
closing price > opening price.

    lines => [
	result => {
	    function => 'mark',
	}
    ],

    tests => [
	gt => 'mark($result, $low) if $close > $open;'
    ],

    sample => {
	test => gt
    }

The next example draws lines at 0 and 100 on a C<logic> graph, simulating the
result of this module.  [Note the seperating comma after the test END.]

    lines => [
	result => {
	    function => 'mark',
	    gtype    => 'logic',
	    style    => {
		line => {
		    width => 2,
		},
	    },
	},
    ],

    tests => <<'END'
	if (defined $close) {
	    if ($close > $open) {
		mark($result, 100);
	    } else {
		mark($result, 0);
	    }
	}
    END
    ,

    sample => {
	test => 'default',
    }


=head2 If you really need it

Two lines are compared and a results line is produced showing high where the
value of the first is greater than the second and low where it is not.  If one
of the values is undefined, the result is undefined.

By default the result line will be placed on the C<logic> graph, but it can
appear anywhere.  Normally the high and low levels are given suitable positions
on the axis, but these can be specified.

Where the comparison stays the same, the resulting line can be made to decrease
over time.

=head1 OPTIONS

To be any use, there must be a L<Finance::Shares::Model> specification B<lines>
entry that has a B<function> field declaring the module's name.  Then the
entry's tag must be used by a B<sample> in some way.  This may be either
directly in a B<line> field, or by referring to it within a B<test>.

The entry must have a B<function> field, C<less_equal>, and a B<line> or
B<lines> field indicating two source lines.

=head3 function

Required.  Must be C<less_equal>.

=head3 line or lines

Required.  An array ref listing two lines.  The result is high if the first line
is greater than the second. 

=head3 graph

If present, this should be a tag declared as a C<charts> resource.  It
identifies a particular graph within a chart page.  A B<gtype> is implied.

=head3 gtype

This specifies the type of graph the function lines should appear on.  It should
be one of C<price>, C<volume>, C<analysis> or C<logic>.  (Default: C<logic>)

=head3 key

This provides the opportunity to identify the line in the Key panel, next to the
B<style>.

=head3 order

The entries on the graph are sorted according to this value, which defaults to
the order required for calculation.  A large integer will bring the line to the
front and a negative number will put it behind all the rest.

Examples

=over

=item -1

The line goes behind the data.

=item 0.5

In front of the data, but only just.

=item 999

Probably the top line.

=back

=head3 shown

1 for the line to be shown, 0 hides it.  (Default: 1)

=head3 style

This is normally a hash ref defining the data's appearance.  See
L<PostScript::Graph::Style> for full details, or L<Finance::Shares::Model/Lines> for
an example.

=head3 min

The Y axis value used for 'false'.  (Default: depends on C<gtype>)

=head3 max

The Y axis value used for 'true'.  (Default: depends on C<gtype>)

=head3 decay

A decimal factor applied to the result line for each date while the result is
still 'true'.  A value of 0.9 makes a shallow decay curve, while 0.1 keeps just
10% of the previous value so falls rapidly.  (Default: 1.0)

=head3 ramp

A number added to the result line for each date while the result is still
'true'.  A value of -10 produces a shallower straight line than a value of -100.
(Default: 0)

Depending on other values, C<ramp> and C<decay> can be combined to form various
curves.

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

Functions are invoked from their own modules, all with lower-case names such
as L<Finance::Shares::moving_average>.  The nitty-gritty on how to write each
line specification are found there.

The quote data is stored in a L<Finance::Shares::data> object.
For information on writing additional line functions see
L<Finance::Share::Function> and L<Finance::Share::Line>.
Also, L<Finance::Share::test> covers writing your own tests.

=cut

