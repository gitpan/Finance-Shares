package Finance::Shares::value;
our $VERSION = 1.01;
use strict;
use warnings;
use Finance::Shares::Support qw(out show);
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
    undef $o->{line};

    $o->add_line('line', 
	    gtype  => $o->{gtype}  || 'price',
	    key    => $o->{key}    || "$o->{gtype} = $o->{value}",
	    style  => $o->{style},
	    shown  => $o->{shown},
	    order  => $o->{order},
	);
}

sub build {
    my $o = shift;
    my $q = $o->chart->data;
    my $l = $o->line('line');
    my $first = $q->date_to_idx( $q->nearest($q->{first}) );
    my $last  = $q->date_to_idx( $q->nearest($q->{last}, 1) );
    my $start = $q->date_to_idx( $q->nearest($q->{start}) );
    my $end   = $q->date_to_idx( $q->nearest($q->{end}, 1) );

    $l->{data}[$first] = $o->{value};
    $l->{data}[$last]  = $o->{value};
    $l->interpolate();
}

__END__
=head1 NAME

Finance::Shares::value - A line representing a constant value

=head1 SYNOPSIS

Two examples of how to specify a value line, one showing the minimum required
and the other illustrating all the possible fields.

    use Finance::Shares::Model;
    use Finance::Shares::value;

    my @spec = (
	...
	lines => [
	    ...
	    minimal => {
		function => 'value',
		value    => 350,
	    },
	    full = {
		function => 'value',
		graph    => 'Stock Prices',
		gtype    => 'price',
		value    => 350,
		key      => 'Price = £3.50',
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

This module draws a horizontal line on a graph at a level specified by the user.

=head1 OPTIONS

To be any use, there must be a L<Finance::Shares::Model> specification B<lines>
entry that has a B<function> field declaring the module's name.  Then the
entry's tag must be used by a B<sample> in some way.  This may be either
directly in a B<line> field, or by referring to it within a B<test>.

The entry must have a B<function> field, C<value>.  The position of the line is
determined by a B<value> field, and a B<gtype> field should be specified for any
graph other than C<price>.  Unusually, there is no B<line> field as it uses no
external data.

=head3 function

Required.  Must be C<value>.

=head3 value

Required.  A number usually (though not necessarily) within the range of the
graph's Y axis.

=head3 graph

If present, this should be a tag declared as a C<charts> resource.  It
identifies a particular graph within a chart page.  A B<gtype> is implied.

=head3 gtype

Required, unless B<graph> is given.  This specifies the type of graph the function
lines should appear on.  It should be one of C<price>, C<volume>, C<analysis> or
C<level>.  (Default: C<price>)

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

