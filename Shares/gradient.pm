package Finance::Shares::gradient;
our $VERSION = 1.03;
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

    $o->common_defaults('analysis');
    $o->{period} = 5 unless defined $o->{period};
    $o->{period} = 1 if $o->{period} < 1;
    $o->{strict} = 0 unless defined $o->{strict};

    $o->add_line('grad', 
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
    return $o->{strict} ? $o->{period}/2 + 1 : $o->{period};
}

sub build {
    my $o = shift;
    my $q = $o->{quotes};
    my $s = $o->{line}[0][0];
    my $v = $s->{data};
    my $d = $q->dates;
    my @points;
    
    my $end   = $#$v;
    my $nhi   = int($o->{period}/2);
    my $nlo   = $nhi - $o->{period};
    my $wmax  = -$nlo;
    my $first = $o->{strict} ? -$nlo : $o->{period};
    my $last  = $o->{strict} ? $end - $nhi : $end;
    for (my $p = 1; $p <= $first; $p++) {
	push @points, undef;
    }
    for (my $p = $first; $p <= $last; $p++) {
	my $res;
	if (defined $v->[$p]) {
	    my $tdy = 0;
	    my $twt = 0;
	    foreach my $n ($nlo .. $nhi) {
		next unless $n;
		my $weight = $wmax - abs($n) + 1;
		my $p1 = $p + $n;
		if ($p1 >= 0 and $p1 <= $end and defined $v->[$p1]) {
		    my $dy = ($n > 0) ? $v->[$p1] - $v->[$p] : $v->[$p] - $v->[$p1];
		    $tdy += $weight * $dy;
		    $twt += $weight;
		}
	    }
	    $res = $twt ? $tdy/$twt : undef;
	    #warn "$d->[$p]\: value=$v->[$p], gradient=", (defined $res ? $res : '-'), "\n";
	}
	push @points, $res;
    }
    
    my $l = $o->func_line('grad');
    $l->{data} = \@points;
	
    unless ($l->{key}) {
	my $dtype = $q->dates_by;
	my $src_key = $s->default_key();
	$l->{key} = "$o->{period} $period{$dtype} gradient of '$src_key'";
    }
}

__END__
=head1 NAME

Finance::Shares::gradient - Smoothed rate of change

=head1 SYNOPSIS

Two examples of how to specify a gradient line, one showing the minimum
required and the other illustrating all the possible fields.

    use Finance::Shares::Model;
    use Finance::Shares::gradient;

    my @spec = (
	...
	lines => [
	    ...
	    minimal => {
		function => 'gradient',
	    },
	    full = {
		function => 'gradient',
		graph    => 'Stock Prices',
		gtype    => 'price',
		line     => 'some_line',
		period   => 10,
		strict   => 1,
		key      => '10 day gradient',
		style    => { ... },
		shown    => 1,
		order    => -99,
	    },
	    ...
	],
	...
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

Momentum is calulcated as the difference in value between now and N periods in
the past.  This module calulates an average momentum for those N periods.

Strictly, this should be from -N/2 to +N/2 but then the line is undefined at its
most recent edge.  As this is rarely useful, the default is to use the more
normal -N to 0.  Note that the end section is not accurate - it gives an idea
but it may be wrong.  (So what's new in stock price forecasting?)

When C<period> is 1, the gradient line is a resonable approximation to the rate
of change of the source.

The results are normally displayed on an 'analysis' graph as the changes may be
positive or negative values.  B<WARNING:> if you specify a graph for the
gradient line, it will NOT relate to the Y axis.  '0' will probably be around
the middle (vertically) of the gradient line, while for the Y axis, '0' may well
be below the bottom of the page.

To be any use, there must be a L<Finance::Shares::Model> specification B<lines>
entry that has a B<function> field declaring the module's name.  Then the
entry's tag must be used by a B<sample> in some way.  This may be either
directly in a B<line> field, or by referring to it within a B<test>.

The other main fields are B<line> and B<period>.

=head1 OPTIONS

=head3 function

Required.  Must be C<gradient>.

=head3 graph

If present, this should be a tag declared as a C<charts> resource.  It
identifies a particular graph within a chart page.  A B<gtype> is implied.  (No
default)

=head3 gtype

Required, unless B<graph> is given.  This specifies the type of graph the function
lines should appear on.  It should be one of C<price>, C<volume>, C<analysis> or
C<logic>.  (Default: C<price>)

=head3 line

Identifies the line whose data is to be considered.  (Default: 'close')

=head3 period

The number of values to use.  The actual time will depend on the B<dates> C<by>
field.  (Default: 5)

Normally at least this number of dates will have been read in before the
first date shown on the chart.  However, a small initial gap may be visible if
some of that working data was missing.  Set the B<dates> C<before> field to
adjust this.

=head3 strict

Set this to 1 to get the more accurate, but possibly less useful, spread using -N/2
to +N/2 periods.  (Default: 0)

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

