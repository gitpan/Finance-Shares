package Finance::Shares::standard_deviation;
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
    $o->{no_line} = 0 unless defined $o->{no_line};
    $o->{shown}   = 0 if $o->{no_line};
    $o->{std_devs} = [ -2, -1, 0, 1, 2 ] unless ref($o->{std_devs}) eq 'ARRAY';

    if ($o->{no_line}) {
	$o->add_line('sd0', 
	    graph  => $o->{graph},
	    gtype  => $o->{gtype},
	    key    => '',
	    style  => $o->{style},
	    shown  => $o->{shown},
	    order  => $o->{order},
	);
    } else {
	my $sds = $o->{std_devs};
	my $inc = 0.99/@$sds;
	for (my $i = 0; $i <= $#$sds; $i++) {
	    $o->add_line('sd' . $i, 
		graph  => $o->{graph},
		gtype  => $o->{gtype},
		key    => $o->{key} || '',
		style  => $o->{style},
		shown  => $o->{shown},
		order  => $o->{order} + $i * $inc,
	    );
	}
    }
}

sub value {
    my ($o, $field) = @_;
    $field = 'std_dev' unless defined $field;
    if ($field eq 'mean') {
	return $o->{mean};
    } else {
	return $o->{std_dev};
    }
}


sub build {
    my $o = shift;
    my $q      = $o->{quotes};
    my $src    = $o->{line}[0][0];
    my $values = $src->{data};
    my $dates  = $q->dates;
    my @points;

    my $total  = 0;
    my $ex2    = 0;
    my $count  = 0;
    for (my $i = 0; $i <= $#$values; $i++) {
	my $val = $values->[$i];
	next unless defined $val;
	$total += $val;
	$count++;
	$ex2 += $val * $val;
    }
    $o->{mean} = $count ? $total/$count : 0;
    $o->{std_dev} = $count ? sqrt($ex2/$count - $o->{mean} * $o->{mean}) : 0;
    return unless $count;
    
    if ($o->{no_line}) {
	my $l = $o->line('sd0');
	$l->{data} = [];
    } else {
	my $first = $q->date_to_idx( $q->nearest($q->{first}) );
	my $last  = $q->date_to_idx( $q->nearest($q->{last}, 1) );

	my $sds = $o->{std_devs};
	for (my $i = 0; $i <= $#$sds; $i++) {
	    my $l = $o->line('sd' . $i);
	    my $frac = $sds->[$i];
	    next unless ref($l) and $l->isa('Finance::Shares::Line');

	    my $val = $o->{mean} + $frac * $o->{std_dev};
	    $l->{data}[$first] = $val;
	    $l->{data}[$last]  = $val;
	    $l->interpolate();

	    if ($l->{key}) {
		my $s = (abs $frac == 1) ? '' : "'s";
		$l->{key} .= " ($frac sd$s)";
	    } else {
		my $src_key = $src->default_key();
		my $s = (abs $frac == 1) ? '' : "s";
		$l->{key} = "$frac standard deviation$s from '$src_key'";
	    }
	}
    }
}


__END__
=head1 NAME

Finance::Shares::standard_deviation - Highest value of a given line

=head1 SYNOPSIS

Two examples of how to specify a standard_deviation line, one showing the minimum
required and the other illustrating all the possible fields.
The value function returns the mean as well as the standard deviation of the
source line.

    use Finance::Shares::Model;
    use Finance::Shares::standard_deviation;

    my @spec = (
	...
	lines => [
	    ...
	    minimal => {
		function => 'standard_deviation',
	    },
	    full = {
		function => 'standard_deviation',
		no_line  => 0,
		line     => 'some_line',
		graph    => 'Stock Prices',
		gtype    => 'price',
		key      => 'standard_deviation price',
		style    => { ... },
		shown    => 1,
		order    => -99,
	    },
	    ...
	],

	tests => [
	    values => {
		before => q(
		    my $mean = value($full, 'mean');
		    my $sdev = value($full, 'std_dev');
		),
	    },
	],
	
	samples => [
	    ...
	    one => {
		lines => ['full', 'minimal'],
		tests => 'values',
		...
	    }
	],
    );

    my $fsm = new Finance::Shares::Model( @spec );
    $fsm->build();

=head1 DESCRIPTION

This module calculates the standard_deviation value found in the source line and
displays a line at that value.  It also returns the C<mean> and standard
deviation (C<std_dev>) as values that can be used by a code fragment.

    my $mean = value( $source_line, 'mean' );
    my $sdev = value( $source_line, 'std_dev');
    
To be any use, there must be a L<Finance::Shares::Model> specification B<lines>
entry that has a B<function> field declaring the module's name.  Then the
entry's tag must be used by a B<sample> in some way.  This may be either
directly in a B<line> field, or by referring to it within a B<test>.

The other main fields are B<line>, B<shown> and B<no_line>.

=head1 OPTIONS

=head3 function

Required.  Must be C<standard_deviation>.

=head3 graph

If present, this should be a tag declared as a C<charts> resource.  It
identifies a particular graph within a chart page.  A B<gtype> is implied.  (No
default)

=head3 gtype

Required, unless B<graph> is given.  This specifies the type of graph the function
lines should appear on.  It should be one of C<price>, C<volume>, C<analysis> or
C<level>.  (Default: C<price>)

=head3 line

Identifies the line whose data is to be considered.  (Default: 'close')

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

=head3 no_line

If set to 1, this stops the line data being stored and, of course, the line is
not shown.  The module's value is still available to code fragements, though.
(Default: 0)

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


