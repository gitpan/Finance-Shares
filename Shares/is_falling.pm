package Finance::Shares::is_falling;
our $VERSION = 1.01;
use strict;
use warnings;
use Finance::Shares::Support qw(%period unique_name shown_style out show);
use Finance::Shares::Function;
use Finance::Shares::gradient;
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
    $o->{period} = 0 unless defined $o->{period};
    
    my $source = $o->{line}[0];
    my $uname  = unique_name( 'gradient' );
    $o->{line}[0] = $uname;

    my ($shown, $style) = shown_style( $o->{gradient} );
    my $h      = {
	function => 'gradient',
	line     => [ $source ],
	uname    => $uname,
	shown    => $shown,
	style    => $style,
	strict   => $o->{strict},
	period   => $o->{period},
    };

    my $data = $o->{quotes};
    my $fsm  = $data->model;
    $fsm->add_option('lines', $uname, $h);

    my $dtype = $data->dates_by;
    $o->add_line('fall', 
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
}

sub lead_time {
    my $o = shift;
    return 1;
}

sub build {
    my $o = shift;
    my $q = $o->{quotes};
    my $d = $q->dates;
    my $l = $o->line('fall');

    my $gline = $o->{line}[0][0];
    my $grad  = $gline->{data};
    my @srcs  = $gline->function->source_lines;
    my $skey  = $srcs[0][0]{key};

    my @points;
    my $level = $l->{lmin};
    my $prev;
    for (my $i = 0; $i <= $#$d; $i++) {
	my $res;
	my $v = $grad->[$i];
	if (defined $v) {
	    my $cond = ($v < 0);
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
   
    $l->{data} = \@points;
    unless ($l->{key}) {
	my $dtype = $q->dates_by;
	$l->{key} = "falling '$skey'";
	$l->{key} .= " averaged over $o->{period} $dtype" if $o->{period};
    }
}

__END__
=head1 NAME

Finance::Shares::is_falling - Indicate direction of trades

=head1 SYNOPSIS

Two examples of how to specify a falling line, one showing the minimum
required and the other illustrating all the possible fields.

    use Finance::Shares::Model;
    use Finance::Shares::is_falling;

    my @spec = (
	...
	lines => [
	    ...
	    minimal => {
		function => 'is_falling',
	    },
	    full = {
		function => 'is_falling',
		key      => 'on balance volume',
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

This line attempts to interpret the volume of trades as an ebb and flow.  It is
assumed that when the closing price is higher than the previous day, the volume
was buying, and that selling is happening if the price is falling.

Although a gross simplification, it is still a useful approximation.

The results are normally displayed on an 'analysis' graph as the changes may be
positive or negative values.  B<WARNING:> if you specify a graph for the
falling line, it will NOT relate to the Y axis.  '0' will probably be around
the middle (vertically) of the falling line, while for the Y axis, '0' may well
be below the bottom of the page.

To be any use, there must be a L<Finance::Shares::Model> specification B<lines>
entry that has a B<function> field declaring the module's name.  Then the
entry's tag must be used by a B<sample> in some way.  This may be either
directly in a B<line> field, or by referring to it within a B<test>.

There are no significant options.

=head1 OPTIONS

=head3 function

Required.  Must be C<is_falling>.

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

