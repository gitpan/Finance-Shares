package Finance::Shares::percent_band;
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
    my $percent = $o->{percent}/100;
    my (@highs, @lows);

    for (my $i = 0; $i <= $#$d; $i++) {
	my ($hi, $lo);

	my $val = $v->[$i];
	if (defined $val) {
	    my $diff = $val * $percent;
	    $hi = $val + $diff;
	    $lo = $val - $diff;
	}
	
	push @highs, $hi;
	push @lows,  $lo;
#	warn "$i\: ",
#	    "\tnew=", (defined($new) ? $new : '-'),
#	    "\thi=", (defined($hi) ? $hi : '-'),
#	    "\tlo=", (defined($lo) ? $lo : '-'), "\n";
    }
    my $h = $o->func_line('high');
    my $l = $o->func_line('low');
    $h->{data} = \@highs;
    $l->{data} = \@lows;

    $l->{key} = "$o->{percent}\% below '$s->{key}'" unless $l->{key};
    $h->{key} = "$o->{percent}\% above '$s->{key}'" unless $h->{key};
}

__END__
=head1 NAME

Finance::Shares::percent_band - Calculate a Bollinger band

=head1 SYNOPSIS

Two examples of how to specify a Bollinger band, one showing the minimum
required and the other illustrating all the possible fields.

    use Finance::Shares::Model;
    use Finance::Shares::percent_band;

    my @spec = (
	...
	lines => [
	    ...
	    minimal => {
		function => 'percent_band',
	    },
	    full = {
		function => 'percent_band',
		graph    => 'Stock Prices',
		gtype    => 'price',
		line     => 'some_line',
		percent  => 3,
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

Boundary lines are drawn a fixed percentage above and below the source line.

To be any use, there must be a L<Finance::Shares::Model> specification B<lines>
entry that has a B<function> field declaring the module's name.  Then the
entry's tag must be used by a B<sample> in some way.  This may be either
directly in a B<line> field, or by referring to it within a B<test>.

The other main fields are B<line> and B<percent>.

=head1 OPTIONS

=head3 function

Required.  Must be C<percent_band>.

=head3 graph

If present, this should be a tag declared as a C<charts> resource.  It
identifies a particular graph within a chart page.  A B<gtype> is implied.  (No
default)

This should be the graph where B<line> appears.

=head3 gtype

Required, unless B<graph> is given.  This specifies the type of graph the function
lines should appear on.  It should be one of C<price>, C<volume>, C<analysis> or
C<logic>.  (Default: C<price>)

This should be the gtype for B<line>.

=head3 line

Identifies the source line at the centre of the band.  (Default: 'close')

=head3 percent

The boundary lines are this percentage value above and below the source line.

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

