package Finance::Shares::exponential_average;
our $VERSION = 1.00;
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
    $o->{period} = 5 unless defined $o->{period};
    $o->{factor} = 1 unless defined $o->{factor};

    $o->add_line('expo', 
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
    my $s = $o->{line}[0][0];
    my $v = $s->{data};
    my $d = $q->dates;
    my @points;
    
    my $level = 0;
    my $total = 0;
    my $count = 0;
    my $w1 = $o->{period} ? 1/$o->{period} : 0;
    my $w2 = 1 - $w1;
    for (my $i = 0; $i <= $#$d; $i++) {
	my $val = $v->[$i];
	my $date = $d->[$i];
	if (defined $val) {
	    if ($count >= $o->{period}) {
		$level = $level * $w2 + $val * $w1;
		push @points, $level;
	    } else {
		$count++;
		$total += $val;
		$level = $total/$count;
		push @points, undef;
	    }
	} else {
	    push @points, undef;
	}
    }
    my $l = $o->line('expo');
    $l->{data} = \@points;
	
    unless ($l->{key}) {
	my $dtype = $q->dates_by;
	my $src_key = $s->default_key();
	$l->{key} = "$o->{period} $period{$dtype} exponential average of '$src_key'";
    }
}


__END__
=head1 NAME

Finance::Shares::exponential_average - Calculate an N-period exponential average

=head1 SYNOPSIS

Two examples of how to specify a exponential average line, one showing the minimum
required and the other illustrating all the possible fields.

    use Finance::Shares::Model;
    use Finance::Shares::exponential_average;

    my @spec = (
	...
	lines => [
	    ...
	    minimal => {
		function => 'exponential_average',
	    },
	    full = {
		function => 'exponential_average',
		graph    => 'Stock Prices',
		gtype    => 'price',
		line     => 'some_line',
		period   => 10,
		key      => '10 day moving average',
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

This module calculates the moving average of some other value, usually on the
same graph.

To get the line to appear, there must be an entry within the B<lines> block of
a L<Finance::Shares::Model> specification. This hash ref must have a B<function>
field with the value C<exponential_average>.  
The entry's tag must then appear in the C<line> field of a B<sample>.

The other main fields are B<line>, B<gtype> or B<graph>, and B<period>.

=head1 OPTIONS

=head3 function

Required.  Must be C<exponential_average>.

=head3 graph

If present, this should be a tag declared as a C<charts> resource.  It
identifies a particular graph within a chart page.  A B<gtype> is implied.  (No
default)

=head3 gtype

Required, unless B<graph> is given.  This specifies the type of graph the function
lines should appear on.  It should be one of C<price>, C<volume>, C<analysis> or
C<level>.  (Default: C<price>)

=head3 line

Identifies the line whose data is to be averaged.  (Default: 'close')

=head3 period

The number of values to use.  The actual time will depend on the B<dates> C<by>
field.  (Default: 5)

Normally at least this number of dates will have been read in before the
first date shown on the chart.  However, a small initial gap may be visible if
some of that working data was missing.  Set the B<dates> C<before> field to
adjust this.

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

