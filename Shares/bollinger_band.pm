package Finance::Shares::bollinger_band;
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
    $o->{period} = 20 unless defined $o->{period};
    $o->{sd}     = 2 unless defined $o->{sd};

    $o->add_line('high', 
	    graph  => $o->{graph},
	    gtype  => $o->{gtype},
	    key    => $o->{key} || '',
	    style  => $o->{style},
	    shown  => $o->{shown},
	    order  => $o->{order},
	);

    $o->add_line('low', 
	    graph  => $o->{graph},
	    gtype  => $o->{gtype},
	    key    => $o->{key} || '',
	    style  => $o->{style},
	    shown  => $o->{shown},
	    order  => $o->{order},
	);
}

sub lead_time {
 my $o = shift;
 return $o->{period};
}

sub build {
    my $o = shift;
    my $q = $o->{quotes};
    my $d = $q->dates;
    my $s = $o->{line}[0][0];
    my $v = $s->{data};
    my (@highs, @lows);

    ## build lead time
    my $start  = 0;
    my $end    = $#$v;
    my $total  = 0;
    my $ex2    = 0;
    my $count  = 0;
    my $first  = $start;
    while ($count < $o->{period} and $first <= $end) {
	my $val = $v->[$first];
	$first++;
	push @lows, undef;
	push @highs, undef;
	next unless defined $val;
	$total += $val;
	$count++;
	$ex2 += $val * $val;
	#warn "count=$count, val=$val, total=$total, ex2=$ex2\n";
    }
    return undef if $count < $o->{period};
    
    ## calculate standard deviation
    my $mean = $total/$count;
    my $sd   = sqrt($ex2/$count - $mean * $mean);
    my $gap  = $o->{period};
    for (my $i = $first; $i <= $end; $i++) {
	my ($old, $new, $hi, $lo);
	
	$new = $v->[$i];
	if (defined $new) {
	    $total += $new;
	    $ex2 += ($new * $new);
	    
	    $old = $v->[$i-$gap];
	    while (not defined $old) {
		$old = $v->[$i- --$gap];
	    }

	    $total -= $old;
	    $ex2 -= ($old * $old);
	    $mean = $total/$count;
	    $sd   = sqrt($ex2/$count - $mean * $mean);
	    #warn "total=$total, count=$count, mean=$mean, sd=$sd\n";
	    
	    my $diff = $sd * $o->{sd};
	    $hi = $new + $diff;
	    $lo = $new - $diff;
	} else {
	    ++$gap;
	}
	
	push @highs, $hi;
	push @lows,  $lo;
#	warn "$i\: ",
#	    "\tnew=", (defined($new) ? $new : '-'),
#	    "\thi=", (defined($hi) ? $hi : '-'),
#	    "\tlo=", (defined($lo) ? $lo : '-'), "\n";
    }
    my $h = $o->line('high');
    my $l = $o->line('low');
    $h->{data} = \@highs;
    $l->{data} = \@lows;

    my $dtype = $q->dates_by;
    my $desc;
    if ($o->{period} == 20 and $o->{sd} == 2) {
	$desc = "bollinger band";
    } else {
	$desc = "$o->{period} $period{$dtype}, $o->{sd} standard deviation";
	$desc .= 's' if $o->{sd} != 1;
    }
    $l->{key} = "$desc below '$s->{key}'" unless $l->{key};
    $h->{key} = "$desc above '$s->{key}'" unless $h->{key};
}

__END__
=head1 NAME

Finance::Shares::bollinger_band - Calculate a Bollinger band

=head1 SYNOPSIS

Two examples of how to specify a Bollinger band, one showing the minimum
required and the other illustrating all the possible fields.

    use Finance::Shares::Model;
    use Finance::Shares::bollinger_band;

    my @spec = (
	...
	lines => [
	    ...
	    minimal => {
		function => 'bollinger_band',
	    },
	    full = {
		function => 'bollinger_band',
		graph    => 'Stock Prices',
		gtype    => 'price',
		line     => 'some_line',
		period   => 10,
		sd       => 1.65,
		style    => { ... },
		shown    => 1,
		order    => -99,
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

A Bollinger band is marked by high and low boundary lines drawn a number of
standard deviations above and below a source line.

To be any use, there must be a L<Finance::Shares::Model> specification B<lines>
entry that has a B<function> field declaring the module's name.  Then the
entry's tag must be used by a B<sample> in some way.  This may be either
directly in a B<line> field, or by referring to it within a B<test>.

The other main fields are B<line>, B<sd> and B<period>.

=head1 OPTIONS

=head3 function

Required.  Must be C<bollinger_band>.

=head3 graph

If present, this should be a tag declared as a C<charts> resource.  It
identifies a particular graph within a chart page.  A B<gtype> is implied.  (No
default)

=head3 gtype

Required, unless B<graph> is given.  This specifies the type of graph the function
lines should appear on.  It should be one of C<price>, C<volume>, C<analysis> or
C<level>.  (Default: C<price>)

=head3 line

Identifies the source line at the centre of the band.  (Default: 'close')

=head3 period

The number of values to use.  The actual time will depend on the B<dates> C<by>
field.  (Default: 20)

Normally at least this number of dates will have been read in before the
first date shown on the chart.  However, a small initial gap may be visible if
some of that working data was missing.  Set the B<dates> C<before> field to
adjust this.

=head3 sd

The number of standard deviations to use.

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

=head1 BUGS

Please let me know when you suspect something isn't right.  A short script
working from a CSV file demonstrating the problem would be very helpful.

Not so much bugs but temporary infecilities due to the difficulties of
controlling two lines from one specification.  No user key is available and it
is not possible to have complete control of the style unless one of the lines
dissappears from the Key.

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

