package Finance::Shares::compare;
our $VERSION = 1.03;
use strict;
use warnings;
use Log::Agent;
use Finance::Shares::Function;
use Finance::Shares::Support qw(out show is_date name_flatten);
our @ISA = 'Finance::Shares::Function';

sub new {
    my $class = shift;
    my $o = new Finance::Shares::Function(@_);
    bless $o, $class;
}

sub initialize {
    my $o = shift;

    $o->common_defaults('analysis', 'data/open', 'data/close');

    my $chart = $o->chart;
    my $page  = $chart->name;
    my $model = $chart->model;

    my $lines = $o->{line};
    for (my $i = 1; $i <= $#$lines; $i++) {
	my $name = $lines->[$i];
	my $id = name_flatten($name, '_');
	$o->add_line($id,
	    gtype  => $o->{gtype},
	    graph  => $o->{graph},
	    key    => $o->{key} || '',
	    style  => $o->{style},
	    shown  => $o->{shown},
	    order  => $o->{order},
	);
    }
}

sub build {
    my $o = shift;
    my $q = $o->{quotes};
    my $d = $o->common_dates;
    my $zdate = $o->zero_date($d);
    my $zi = $q->date_to_idx($zdate) || 0;
    #warn "zdate=$zdate, zi=$zi";

    my $result = $o->{fsls};
    my $source = $o->{line};
    my $base = $source->[0][0];
    my $base_key = $base->default_key();
    #warn "base=",$base->name, ", base_key=$base_key\n";
    my $bd = $base->{data};
    my $bdoffset = $bd->[$zi];

    for (my $s = 1; $s <= $#$source; $s++) {
	my $src = $source->[$s][0];
	my $res = $result->[$s-1];
	my $src_key  = $src->default_key();
	$res->{key} = "'$src_key' relative to '$base_key'";
	#warn "src=", $src->name, " src_key=$src_key\n";

	my $sd = $src->{data};
	my @points;
	if (defined $bdoffset and defined $sd->[$zi]) {
	    my $offset = $bdoffset - $sd->[$zi];
	    for (my $i = 0; $i <= $#$d; $i++) {
		my $sv = $sd->[$i];
		my $bv = $bd->[$i];
		push @points, (defined($sv) and defined($bv)) ? ($sv - $bv + $offset) : undef;
	    }
	}
	$res->{data} = \@points;
    }
}



sub common_dates {
    my $o = shift;
    my $q = $o->{quotes};
    my $d = $q->dates;
    my @dates = @{$q->dates};
    my $source = $o->{line};
    for (my $i = 0; $i <= $#$d; $i++) {
	my $all = 1;
	foreach my $ar (@$source) {
	    foreach my $src (@$ar) {
		my $sd = $src->{data};
		$all = 0, last unless defined $sd->[$i];
	    }
	    last unless $all;
	}
	$dates[$i] = undef unless $all;
    }
    return \@dates;
}

sub zero_date {
    my ($o, $d) = @_;
    my $zero = is_date($o->{zero}) ? $o->{zero} : '0000-00-00';
   
    my ($found, $best);
    for (my $i = 0; $i <= $#$d; $i++) {
	my $date = $d->[$i];
	next unless defined $date;
	$best = $date;
	$found = $date, last if $zero le $date;
    }
    return ($found || $best || '');
}

__END__
=head1 NAME

Finance::Shares::compare - Present one line relative to another

=head1 SYNOPSIS

Two examples of how to compare lines, one showing the minimum
required and the other illustrating all the possible fields.

    use Finance::Shares::Model;
    use Finance::Shares::compare;

    my @spec = (
	...
	lines => [
	    ...
	    minimal => {
		function => 'compare',
		lines    => [qw(base_line line1 line2)],
	    },
	    full = {
		function => 'compare',
		graph    => 'Stock Prices',
		gtype    => 'price',
		lines    => ['base_line', 'other_line'],
		key      => 'comparing base and other',
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

This module produces a line on the B<analysis> graph comparing the values of two
lines.

To be any use, there must be a L<Finance::Shares::Model> specification B<lines>
entry that has a B<function> field declaring the module's name.  Then the
entry's tag must be used by a B<sample> in some way.  This may be either
directly in a B<line> field, or by referring to it within a B<test>.

The other main fields are B<lines>, B<gtype> or B<graph>.
An additional field is B<zero>.

=head1 OPTIONS

=head3 function

Required.  Must be C<compare>.

=head3 graph

If present, this should be a tag declared as a C<charts> resource.  It
identifies a particular graph within a chart page.  A B<gtype> is implied.  (No
default)

=head3 gtype

Required, unless B<graph> is given.  This specifies the type of graph the function
lines should appear on.  It should be one of C<price>, C<volume>, C<analysis> or
C<logic>.  (Default: C<price>)

=head3 lines

This array ref should hold the names (tags or fully qualified) of more than one
line.  The first is considered the base line and the others are drawn relative
to it.

=head3 zero

An optional date taken as the zero point for all comparisons.  (Default: first
chart date)

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

