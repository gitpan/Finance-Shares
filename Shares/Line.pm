package Finance::Shares::Line;
our $VERSION = 1.03;
use strict;
use warnings;
use Log::Agent;
use Finance::Shares::Support qw(
	$highest_int $lowest_int
	out out_indent show
	valid_gtype is_date name_split name_join
    );

our $monotonic = 0;

=head1 NAME

Finance::Shares::Line - A single chart line or data series

=head1 SYNOPSIS

    use Finance::Shares::Line;

    my $l = new Finance::Shares::Line(
	gtype => 'price',
	key   => 'Some text',
	order => -1,
	style => {
	    # PostScript::Graph::Style options
	    },
	shown => 0,
    };

    my $name = $l->name;
    my $data = $l->data;

=head1 DESCRIPTION

Finance::Shares::Line objects are components of functions derived from
Finance::Shares::Function such as Finance::Shares::data or
Finance::Shares::moving_average.  Each Finance::Shares::Line holds a sequence of
zero or more Y axis values indexed by YYYY-MM-DD dates.  Additional information
like the display style or key text is also maintained.  See
L<Finance::Shares::Function> for more details.

=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my $o = {
	# These should probably be included in add_line()'s hash
	gtype   => '',		    # REQUIRED: price/volume/analysis/logic
	key     => undef,	    # Identify line style in Key panel
	style   => undef,	    # Control appearance
	shown   => 1,		    # Only needed to over-ride 'style'
	order   => undef,           # Optional z-order positioning
	
	# Finance::Shares::Function::add_line() will set these
	fsfn    => undef,	    # Parent Finance::Shares::Function derived object
	id      => undef,	    # identifies this line within function
	verbose => 1,
	
	# Override for Finance::Shares::Function::build() should set this
	data    => [],		    # Populate with Y axis values, same order as chart's data

	# Finance::Shares::Function::finalize() will set these
	lmin    => $highest_int,
	lmax	=> $lowest_int,
	built   => 0,

	# identifies result of a test
	is_mark => 0,

	@_,
    };
    bless( $o, $class );

    logerr("$o has no 'fsfn' field") unless ref($o->{fsfn}) and $o->{fsfn}->isa('Finance::Shares::Function');
    logerr("$o has no 'id' field") unless defined $o->{id};
    logerr("Line '$o->{id}' gtype field is not a graph type"), return unless valid_gtype($o->{gtype});

    $o->{order} = $monotonic++ unless defined $o->{order};

    out($o, 4, "new $class '$o->{id}'");
    return $o;
}

=head1 new( options )

The options are in hash key/value format.  Every line should have at least the
following fields.

=over 8

=item gtype

The graph type where this line belongs.  It must be one of price, volume,
analysis or logic.  REQUIRED - there is no default.

=item key

The text that identifies this data on the chart's key panel.  (Defaults to line
id.)

=item order

Lines are displayed on the chart in ascending order of this field.  Negative
numbered lines would be displayed before those with no given value.  (Default:
numbered by creation order, starting from 0).

=item shown

True if the line is to be displayed.  Setting this to 0 ensures the line is
hidden.  (Defaults to 1 if C<style> is defined, 0 otherwise.)

=item style

Either a PostScript::Style object or a hash ref containing options for creating
one.  If undefined, it is assumed that the line is hidden, unless C<shown> is
true.  (Default: <undef>)

=back

=cut

=head1 ACCESS METHODS

=cut

sub function {
    return $_[0]->{fsfn};
}

sub chart {
    my $o = shift;
    return $o->{fsfn}->chart;
}

sub graph {
    my $o = shift;
    return $o->{home} if defined $o->{home};
    my $ch = $o->{fsfn}->chart;
    return $o->{graph} || $o->{gtype} unless $ch;
    return $o->{home} = $ch->graph_for($o);
}

=head2 graph( )

If called too soon, this just returns a suitable graph name.  Once the chart has been created, this returns a hash
ref holding all the graph settings.  In which case the name is in the {graphID} field.

    my $g    = $line->graph;
    my $name = (ref($g) eq 'HASH') ? $g->{graphID} : $g;
    my $hash = (ref($g) eq 'HASH') ? $g: {};
    
=cut

sub id {
    return $_[0]->{id};
}

=head2 id( )

Return the line identifier.

=cut

sub name {
    my $o = shift;
    return name_join( $o->{fsfn}->name, $o->{id} );
}

=head2 name( )

Returns the canonical name of the line.

=cut

sub order {
    return $_[0]->{order};
}

=head2 order( )

Return the Z-ordering position of this line.

=cut

sub display {
    my ($o, $date) = @_;
    return $o->{data};
}

=head2 display( )

Access line data intended for display.  Now identical to B<data>.

=cut

sub data {
    my $o = shift;
    return $o->{data};
}

=head2 data( )

Access line data intended for calculations.

=cut


sub npoints {
    my $o = shift;
    return $o->{npoints} || scalar(@{$o->{data}});
}

sub for_scaling {
    return $_[0]->{scale};
}

sub value {
    return $_[0]->function->value;
}

sub is_mark {
    my ($o, $val) = @_;
    $o->{is_mark} = $val if defined $val;
    return $o->{is_mark};
}

### SUPPORT METHODS

sub interpolate {
    my $o = shift;
    my $q = $o->{fsfn}{quotes};
    my $d = $q->dates;
    out($o, 5, "interpolate(), line=" . $o->name);
    
    my $data = $o->{data};
    my ($pi, $ni);
    my @points;
    for (my $i = 0; $i <= $#$d; $i++) {
	if (defined $data->[$i]) {
	    $pi = $i;
	    push @points, $data->[$i];
	} else {
	    undef $ni;
	    foreach my $i1 ($i .. $#$d) {
		$ni = $i1, last if defined $data->[$i1];
	    }
	    if (defined $pi and defined $ni) {
		my $dn = $ni - $i;
		my $dp = $i - $pi;
		my $vn = $data->[$ni];
		my $vp = $data->[$pi];
		push @points, ($vp*$dn + $vn*$dp)/($dp+$dn);
	    }
	}
    }
    $o->{data} = \@points;
}

sub condition_level {
    my ($o, $level) = @_;
    return unless defined $level;

    my $lvl = $level - $o->{lmin};
    $lvl = $lvl*$o->{decay} + $o->{ramp} + $o->{lmin};
    return $lvl;
}

=head2 condition_level( level )

Apply decay and ramp settings to the Y value of a test line.  Returns the new level.

=cut

sub initialize {
    my $o = shift;
    my $fn    = $o->{fsfn};
    my $chart = $fn->chart;
    my $graph = $o->graph;
    my $scale  = 0;
    my $gtype = $o->{gtype};
    if ($gtype) {
	if ($gtype eq 'logic') {
	    $scale = 0;
	} else {
	    $scale = 1 if $graph->{gtype} ne $gtype;
	}
    }
    $scale = $o->{scale} if defined $o->{scale};
    #warn $o->name, ": gtype=$gtype, graph=$graph->{gtype}, scale=$scale\n";

    if ($scale) {
	my $model = $chart->model;
	$model->mark_for_scaling($o);

	$o->{scale} = 1;
	$o->{lmin}  = 0;
	$o->{lmax}  = $fn->{weight};
	$o->{decay} = $fn->{decay};
	$o->{ramp}  = $fn->{ramp};
    } else {
	$o->{lmin}  = $highest_int;
	$o->{lmax}  = $lowest_int;
    }
    out($o, 7, "Initializing line '". $o->name ."' shown=$o->{shown}, style=", $o->{style} || '<none>');
}

sub scale {
    my $o = shift;
    out($o, 5, "scale() line '". $o->name ."'");
    my $fn    = $o->{fsfn};
    my $chart = $o->chart;
    my $g     = $o->graph;
    my $d     = $o->{data};
    $chart->graph_range($g);
   
    ## Calculate transformation
    my ($min1, $max1) = $o->get_range( $chart, $g, $d );
    my ($min2, $max2) = $o->get_range( $chart, $g );
    $min2 = $fn->{min} if defined $fn->{min};
    $max2 = $fn->{max} if defined $fn->{max};
    my $factor = ($max1 == $min1 ? 1 : ($max2 - $min2)/($max1 - $min1));
    out($o, 6, "scale: ($min1->$max1) * $factor = ($min2->$max2)");
    
    ## Transform each value
    my $min = $highest_int;
    my $max = $lowest_int;
    for (my $i = 0; $i <= $#$d; $i++) {
	my $value = $d->[$i];
	next unless defined $value;
	$value -= $min1;
	$value *= $factor;
	$value += $min2;
	$d->[$i] = $value;
	$min = $value if $value < $min;
	$max = $value if $value > $max;
    }
    #warn "min=$min, max=$max";

    ## Update min/max
    if ($min < $highest_int and $max > $lowest_int) {
	$o->{lmin} = $min if $min < $o->{lmin};
	$o->{lmax} = $max if $max > $o->{lmax};
	$o->{lmax} = $o->{max} if defined $o->{max};
	$o->{lmin} = $o->{min} if defined $o->{min};
	$g->{gmin} = $min if $min < $g->{gmin};
	$g->{gmax} = $max if $max > $g->{gmax};
    }
    out($o, 7, $o->name ,"=($o->{lmin}->$o->{lmax}), $g->{name}=($g->{gmin}->$g->{gmax})");
}

sub get_range {
    my ($o, $chart, $g, $d) = @_;
    my $min = $highest_int;
    my $max = $lowest_int;
    if ($d) {
	for (my $i = 0; $i <= $#$d; $i++) {
	    my $value = $d->[$i];
	    next unless defined $value;
	    $min = $value if $value < $min;
	    $max = $value if $value > $max;
	}
    } else {
	my $margin = $chart->axis_margin($g);
	$min = $g->{gmin} + $margin;
	$max = $g->{gmax} - $margin;
    }

    $min    = 0      if (not defined $min) or $min == $highest_int or $o->{zero};
    $max    = $min+1 if (not defined $max) or $max == $lowest_int;
    return ($min, $max);
}

sub finalize {
    my $o = shift;
    out($o, 6, "finalizing Line ", $o->name);
    my $q = $o->chart->data;
    
    unless (defined $o->{key}) {
	my @f = name_split $o->name;
	my $fntag = $f[3] || '';
	my $fnline = $f[4] || 'default';
	my $fname = $o->{fsfn}{function};
	$o->{key} = "line '$fntag/$fnline' ($fname)" unless $o->{key};
    }

    my $d = $o->{data};
    logerr("Line '$o->{id}' has no data"), return unless ref($d) eq 'ARRAY';

    my $min = $highest_int;
    my $max = $lowest_int;
    my $npoints = 0;
    my $dstart = $q->date_to_idx( $q->start ) || 0;
    my $dend = $q->date_to_idx( $q->end ) || 0;
    for (my $i = $dstart; $i <= $dend; $i++) {
	my $v = $d->[$i];
	next unless defined $v;
	$min = $v if $v < $min;
	$max = $v if $v > $max;
	$npoints++;
    }
    $o->{npoints} = $npoints;
    
    $min = 0 if $o->{zero};
    $o->{lmin} = $min if $min < $highest_int;
    $o->{lmax} = $max, $o->{built} = 1 if $max > $lowest_int;
    $o->{key} .= ' (Shape only)' if $o->{scale};
    out($o, 7, "Line::finalize ($o->{id}) lmin=$o->{lmin}, lmax=$o->{lmax}, ", scalar(@{$o->{data}}), " data points");
}


sub default_key {
    my $o = shift;
    return $o->{key} || '';
}

=head1 BUGS

Please do let me know when you suspect something isn't right.  A short script
working from a CSV file demonstrating the problem would be very helpful.

=head1 AUTHOR

Chris Willmot, chris@willmot.org.uk

=head1 LICENCE

Copyright (c) 2003 Christopher P Willmot

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
L<Finance::Shares::Function> and L<Finance::Shares::Line>.
Also, L<Finance::Shares::Code> covers writing your own tests.

=cut

1;

