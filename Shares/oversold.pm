package Finance::Shares::oversold;
our $VERSION = 1.01;
use strict;
use warnings;
use Finance::Shares::Support qw(%period $default_line_style
				$highest_int $lowest_int
				unique_name shown_style out show);
use Finance::Shares::Function;
use Finance::Shares::gradient;
use Finance::Shares::momentum;
use Finance::Shares::rate_of_change;
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

    $o->common_defaults('level', 'close');
    $o->level_defaults;
    $o->{period}   = 0 unless defined $o->{period};
    $o->{acceptable} = 1 unless defined $o->{acceptable};
    $o->{momentum} = 'momentum' unless defined $o->{momentum};
    
    # prepare gradient line
    my $source = $o->{line}[0];
    my $uname  = unique_name( 'gradient' );
    $o->{line}[0] = $uname;

    my ($shown, $style) = shown_style( $o->{gradient} );
    $o->{show_lines} = $shown;
    my $h      = {
	function => $o->{momentum},
	graph    => 'Oversold gradient',
	gtype    => 'analysis',
	line     => [ $source ],
	uname    => $uname,
	shown    => $shown,
	style    => $style,
	order    => $o->{order},
	strict   => $o->{strict},
	period   => $o->{period},
    };

    my $data = $o->{quotes};
    my $fsm  = $data->model;
    $fsm->add_option('lines', $uname, $h);

    # the main result line
    $o->add_line('line', 
	graph  => $o->{graph},
	gtype  => $o->{gtype},

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

    # cutoff line
    if ($shown) {
	$o->add_line('boundary', 
	    graph    => 'Oversold gradient',
	    gtype    => 'analysis',
	    key      => '',
	    shown    => $shown,
	    style    => $style,
	    order    => $o->{order},
	);
    }
}

sub lead_time {
    my $o = shift;
    return 1;
}

sub build {
    my $o = shift;
    my $q = $o->{quotes};
    my $d = $q->dates;
    my $l = $o->line('line');

    my $gline = $o->{line}[0][0];
    my $grad  = $gline->{data};
    my @srcs  = $gline->function->source_lines;
    my $skey  = $srcs[0][0]{key};

    # calculate mean and standard deviation
    my $sum2 = 0;
    my $total = 0;
    my $count = 0;
    my $min = $highest_int;
    my $max = $lowest_int;
    for (my $i = 0; $i <= $#$d; $i++) {
	my $v = $grad->[$i];
	next unless defined $v;
	$count++;
	$total += $v;
	$sum2  += $v*$v;
	$min = $v if $v < $min;
	$max = $v if $v > $max;
    }
    my $cutoff = $l->{lmin};
    
    my @points;
    if ($count) {
	my $mean = $total/$count;
	my $sd   = sqrt( $sum2/$count - $mean*$mean );
	my ($boundary, $percent) = ( $o->{acceptable} =~ /([0-9.eE]+)\s*(%?)/ );
	if ($percent) {
	    $cutoff = $min  + ($boundary/100) * ($max - $min);
	} else {
	    $cutoff = $mean + $boundary * $sd;
	}
	#warn "boundary=$boundary, percent=$percent";
	#warn "min=$min, max=$max";
	
	my $prev;
	my $level = $l->{lmin};
	for (my $i = 0; $i <= $#$d; $i++) {
	    my $res;
	    my $v = $grad->[$i];
	    if (defined $v) {
		my $cond = ($v > $cutoff);
		if (not defined($prev) or $cond != $prev) {
		    $level = ($cond ? $l->{lmax} : $l->{lmin});
		} else {
		    $level = $l->condition_level( $level );
		}
		$res  = $level if defined $prev;
		$prev = $cond;
	    }
	    push @points, $res;
	}
    }
   
    $l->{data} = \@points;
    unless ($l->{key}) {
	my $dtype = $q->dates_by;
	$l->{key} = "oversold '$skey'";
	$l->{key} .= " averaged over $o->{period} $dtype" if $o->{period};
    }

    if ($o->{show_lines}) {
	my $first = $q->date_to_idx( $q->nearest($q->{first}) );
	my $last  = $q->date_to_idx( $q->nearest($q->{last}, 1) );
	
	my $b = $o->line('boundary');
	$b->{data}[$first] = $cutoff;
	$b->{data}[$last]  = $cutoff;
	$b->interpolate();
	$b->{key} = "boundary for oversold '$skey'";
    }
}

__END__
=head1 NAME

Finance::Shares::oversold - Indicate excessive price movement

=head1 SYNOPSIS

Two examples of how to specify a oversold line, one showing the minimum
required and the other illustrating all the possible fields.

    use Finance::Shares::Model;
    use Finance::Shares::oversold;

    my @spec = (
	...
	lines => [
	    ...
	    minimal => {
		function => 'oversold',
	    },
	    full = {
		function   => 'oversold',
		line       => 'close',
		acceptable => 2.65,
		gradient   => 1,
		period     => 5,
		strict     => 0,
		
		key        => 'accelerated buying',
		style      => { ... },
		shown      => 1,
		order      => -99,
		
		graph      => 'Trading prices',
		gtype      => 'price',
		min        => 230,
		max        => 390,
		decay      => 90,
		ramp       => -10,
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

This module attempts to identify where the momentum of increasing prices exceeds
its normal range.  The underlying gradient line can be hidden or visible, and
the cutoff point specified as either a number of standard deviations or
a percentage of the price range.

To be any use, there must be a L<Finance::Shares::Model> specification B<lines>
entry that has a B<function> field declaring the module's name.  Then the
entry's tag must be used by a B<sample> in some way.  This may be either
directly in a B<line> field, or by referring to it within a B<test>.

The main options include B<period>, B<acceptable> and B<gradient>.

=head1 OPTIONS

=head3 function

Required.  Must be C<oversold>.

=head3 graph

If present, this should be a tag declared as a C<charts> resource.  It
identifies a particular graph within a chart page.  A B<gtype> is implied.  (No
default)

=head3 gtype

Required, unless B<graph> is given.  This specifies the type of graph the function
lines should appear on.  It should be one of C<price>, C<volume>, C<analysis> or
C<level>.  (Default: C<level>)

=head3 line

Identifies the line to be considered.  (Default: 'close')

=head3 acceptable

There are two forms.

=over

=item Plain number

The number of standard deviations that are considered normal.  The oversold line
will go high when the corresponding B<number> of gradients is exceeded.  It
reflects a proportion of the actual data.  The following table indicates how
standard deviations relate to percentages of the data in a normal distribution.
    
    sd	    above
    3.00     0.13%
    2.58     0.5%
    2.33     1%
    2.06     2%
    2.00     2.27%
    1.65     5%
    1.29    10%
    1.15    12.5%
    1.00    15.87%
    0.85    20%
    0.68    25%

E.g. '2.33' would highlight approximately the fastest rising 1% of the quotes.

=item String ending in '%'

A percentage of the momentum range.  When the gradient exceeds this value, the
oversold line will go high.  Note that this is a fraction of the gradient
B<range> rather than a proportion of the data quantity.  

E.g. '90%' means that the top 10% of the gradient range is considered unusual
and will be highlighted.

=back

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

=head3 momentum

This should be the name of a function which computes the rate of change of
a line.  Suitable values are 'momentum', 'rate_of_change' or 'gradient'.
(Default: 'momentum')

=head3 period

The number of values to use in smoothing the result.  It is passed to
L<Finance::Shares::gradient>.

The actual time will depend on the B<dates> C<by> field.  (Default: 5)

Normally at least this number of dates will have been read in before the
first date shown on the chart.  However, a small initial gap may be visible if
some of that working data was missing.  Set the B<dates> C<before> field to
adjust this.

=head3 strict

See L<Finance::Shares::gradient>.

=head3 gradient

This controls whether or not the internal gradient and cutoff lines appear and
what style they use.  (Default: 0)

=over

=item '0'

The line is hidden.

=item '1'

The line is visible with the default style.

=item hash ref

The line uses a style created from this specification.

=item L<PostScript::Graph::Style> object

The line is shown with the style given.

=back


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

