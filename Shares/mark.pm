package Finance::Shares::mark;
our $VERSION = 1.01;
use strict;
use warnings;
use Finance::Shares::Support qw(%period out show);
use Finance::Shares::Function;
use Log::Agent;
our @ISA = 'Finance::Shares::Function';

sub new {
    my $class = shift;
    my $o = new Finance::Shares::Function(@_);
    bless $o, $class;

    out($o, 4, "new $class");
    return $o;
}

sub initialize {
    my $o = shift;

    $o->common_defaults;

    my $style = $o->{style};
    if ($style and ref $style eq '') {
	if ($style eq 'circle') {
	    $o->{size} = 12 unless defined $o->{size};
	    $o->{style} = {
		bgnd_outline => 1,
		point => {
		    shape => 'circle',
		    size  => $o->{size},
		    width => $o->{size}/6,
		},
	    };
	} elsif ($style eq 'up_arrow') {
	    $o->{size} = 8 unless defined $o->{size};
	    $o->{style} = {
		point => {
		    shape => 'north',
		    size  => $o->{size},
		    width => $o->{size}/5,
		    y_offset => -$o->{size},
		},
	    };
	} elsif ($style eq 'down_arrow') {
	    $o->{size} = 8 unless defined $o->{size};
	    $o->{style} = {
		point => {
		    shape => 'south',
		    size  => $o->{size},
		    width => $o->{size}/5,
		    y_offset => $o->{size},
		},
	    };
	}
    }
    
    $o->add_line( "mark", 
	    graph  => $o->{graph},
	    gtype  => $o->{gtype},
	    key    => $o->{key} || "mark '$o->{id}'",
	    style  => $o->{style},
	    shown  => $o->{shown},
	    order  => $o->{order},
	);
}

sub build {
    my $o = shift;
    return if $o->built;
    my $q      = $o->{quotes};
    my $src    = $o->{line}[0][0];
    my $values = $src->{data};
    my $dates  = $q->dates;
    out($o, 5, "build mark following '", $src->name);

    my $l = $o->line('mark');
    $l->{data} = [];
    
    my $test = $o->{test};
    if (ref($test) and $test->isa('Finance::Shares::test')) {
	$test->build();
    }
}

__END__
=head1 NAME

Finance::Shares::mark - A line under user program control

=head1 SYNOPSIS

Two examples of how to specify a mark line, one showing the minimum
required and the other illustrating all the possible fields.

    use Finance::Shares::Model;
    use Finance::Shares::mark;

    my @spec = (
	...
	lines => [
	    minimal => {
		function => 'mark',
	    },
	    full = {
		function   => 'mark',
		graph      => 'Stock Prices',
		gtype      => 'price',
		first_only => 1,
		key        => 'these are special',
		style      => { ... },
		shown      => 1,
		order      => 99,
	    },
	],
	
	tests => [
	    t1 => q( mark($full, 300) ),
	],
	
	samples => [
	    ...
	    one => {
		test => 't1',
		...
	    }
	],
    );

    my $fsm = new Finance::Shares::Model( @spec );
    $fsm->build();

=head1 DESCRIPTION

This module allows model B<test> code to write points or lines on the graphs.

B<first_only>, B<style> and B<size> are the most significant options.  Note that
there is no B<line> field as the position is set directly in the program
function call.

=head2 Call Syntax

This module should not be called in the usual way.

There must be a L<Finance::Shares::Model> specification B<lines>
entry that has a B<function> field declaring the module's name.  However, the
entry's tag may only be used in a B<test> code fragment.

    mark( $line_tag, $position );

C<$line_tag> is the B<lines> entry tag with a '$' in front.
C<$position> is either another line tag or a B<scalar variable> holding a Y axis
value.  Note that it cannot be an expression.

B<Example>

    lines => [
	low10 = {
	    function => 'lowest',
	    period   => 10,
	    key      => '10 day low',
	}
	test_line => {
	    function => 'mark',
	},
    ],

    test => q(
	mark( $test_line, $low10 - 5 );
    ),

=head1 OPTIONS

=head3 function

Required.  Must be C<mark>.

=head3 first_only

Setting this to 1 ensures that only the first mark of this block is shown,
rather than a mark for every date that passes the test.  A value of 0 means all
appropriate values are marked.

This module is only ever invoked from a code fragment within a model B<test>.
See L<Finance::Shares::test/Marking the Chart>.  Typically the code fragment
will test the data with some condition such as the following.

    mark($mymark, $close) if $line1 > $line2;

Here the B<mark> module code is only visited for those dates where the value of
$line1 is above $line2.  Typically these would be entries in the model B<lines>
specification, which would include:

    lines => [
	line1 => {
	    ...
	},
	line2 => {
	    ...
	},
	mymark => {
	    function => 'mark',
	    ...
	},
    ],

Imagine a sample with the following data.

    date	    line1   line2   comp
    2003-07-08	    47	    49	    
    2003-07-09	    51	    50	    >
    2003-07-10	    55	    51	    >
    2003-07-11	    53	    52	    >
    2003-07-14	    49	    52
    2003-07-15	    48	    51
    2003-07-16	    51	    50	    >
    2003-07-17	    56	    51	    >

With B<first_only> set to 0, there would be five marks.  But if B<first_only>
was 1, there would be only two - on 2003-07-09 and 2003-07-16.

=over

[Undefined values can confuse this feature.  To be on the safe side
either only use data selected by C<quotes> or be sure to let B<mark()> see the
undefined dates:
    
    mark($mymark, $close) if ($line1 > $line2)
	or (not defined $line1) 
	or (not defined $line2);

B<mark()> assumes that dates missed are failures, and will normally show
a 'first' marker after a gap.  But the gap might be just undefined data and not
a series of dates that failed. B<mark()> adjusts for any undefined values it
sees, but cannot make allowances for undefined values if it is never called for
them.]

=back

=head3 graph

If present, this should be a tag declared as a C<charts> resource.  It
identifies a particular graph within a chart page.  A B<gtype> is implied.  (No
default)

=head3 gtype

Required, unless B<graph> is given.  This specifies the type of graph the function
lines should appear on.  It should be one of C<price>, C<volume>, C<analysis> or
C<level>.  (Default: C<price>)

=head3 key

Most functions generate suitable (if lengthy) entries.  This provides the
opportunity to identify the line in the Key panel, next to the B<style>.

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

There are three special settings, identified by strings C<circle>, C<up_arrow>
and C<down_arrow>.  They are all affected by the B<size> option.  For example,

    style => 'up_arrow',
    size  => 12,

is equivalent to:

    style => {
	bgnd_outline => 0,
	point => {
	    shape    => 'up_arrow',
	    size     => 12,
	    width    => 2,
	    y_offset => -12,
	},
    },

    
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

