package Finance::Shares::multiline_mean;
our $VERSION = 1.03;
use strict;
use warnings;
use Log::Agent;
use Finance::Shares::Function;
use Finance::Shares::Support qw(out show name_join);
our @ISA = 'Finance::Shares::Function';

sub new {
    my $class = shift;
    my $o = new Finance::Shares::Function(@_);
    bless $o, $class;
}

sub initialize {
    my $o = shift;

    $o->common_defaults();

    $o->add_line('mean',
	    gtype  => $o->{gtype},
	    graph  => $o->{graph},
	    key    => $o->{key} || '',
	    style  => $o->{style},
	    shown  => $o->{shown},
	    order  => $o->{order},
	);
}

sub build {
    my $o = shift;
    my $q = $o->{quotes};
    my $d = $q->dates;
    my $l = $o->func_line('mean');

    my @lines;
    foreach my $ar (@{$o->{line}}) {
	push @lines, @$ar;
    }
    my $count = @lines;
    $l->{key} = "mean of $count line" . ($count == 1 ? '' : 's') unless $l->{key};
    
    my @points;
    for (my $i = 0; $i <= $#$d; $i++) {
	my $total = 0;
	my $count = 0;
	foreach my $line (@lines) {
	    next unless defined $line->{data}[$i];
	    $total += $line->{data}[$i];
	    $count++;
	}
	push @points, $count ? $total/$count : undef;
    }
    $l->{data} = \@points;
}

__END__
=head1 NAME

Finance::Shares::multiline_mean - Calculate the average of a number of lines

=head1 SYNOPSIS

Two examples of how to specify a multiline mean, one showing the minimum
required and the other illustrating all the possible fields.

    use Finance::Shares::Model;
    use Finance::Shares::multiline_mean;

    my @spec = (
	...
	lines => [
	    ...
	    minimal => {
		function => 'multiline_mean',
		lines    => '*///line1',
	    },
	    full = {
		function => 'multiline_mean',
		graph    => 'Stock Prices',
		gtype    => 'price',
		lines    => [qw(line1 line2 line3)],
		key      => 'average of 3 lines',
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

This module calculates the average of several lines.  It is probably most
useful when averaging lines created by the same function on several different
samples.

To be any use, there must be a L<Finance::Shares::Model> specification B<lines>
entry that has a B<function> field declaring the module's name.  Then the
entry's tag must be used by a B<sample> in some way.  This may be either
directly in a B<line> field, or by referring to it within a B<test>.

The other main fields are B<lines>, B<gtype> or B<graph>.

=head1 OPTIONS

=head3 function

Required.  Must be C<multiline_mean>.

=head3 graph

If present, this should be a tag declared as a C<charts> resource.  It
identifies a particular graph within a chart page.  A B<gtype> is implied.  (No
default)

=head3 gtype

Required, unless B<graph> is given.  This specifies the type of graph the function
lines should appear on.  It should be one of C<price>, C<volume>, C<analysis> or
C<logic>.  (Default: C<price>)

=head3 lines

This array ref should list the names (tags or fully qualified) of the lines to
be averaged.  For convenience, a wildcard, '*' form can be used to specify 'all the
pages but this one'.  So to find the average of all 10-day moving averages on
a list of stocks:

    lines => [
	'10day' => {
	    function => 'moving_average',
	    period   => 10,
	},
	'mean' => {
	    function => 'multiline_mean',
	    lines    => '*///10day',
	},
    ],

    samples => [
	shares => {
	    stock => [qw(HBOS.L LLOY.L HSBC.L)],
	    line  => '10day',
	},
	summary => {
	    stock => '',
	    line  => 'mean',
	},
    ],

This will produce a 4-page file with the last page showing the average of the
others.
	
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

