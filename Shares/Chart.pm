package Finance::Shares::Chart;
our $VERSION = 1.00;
use strict;
use warnings;
use Log::Agent;
use PostScript::File qw(check_file str);
use PostScript::Graph::Style;
use PostScript::Graph::Key;
use PostScript::Graph::Paper;
use PostScript::Graph::XY;
use Finance::Shares::Support qw(
	$highest_int $lowest_int $default_line_style
	out out_indent show deep_copy
	ymd_from_string day_of_week
	today_as_string decrement_date
	show
    );

## user options allowed for each graph
our $background = [1, 1, 0.93];
our $glyph_ratio = 0.45;
our $graph_options = {
    percent => 20,
    gtype => 'analysis',
    show_dates => 0,
    bars => {
	color => [0.9, 0.9, 0.7],
	inner_color => undef,
	outer_color => undef,
	width => 1,
	inner_width => undef,
	outer_width => undef,
    },
    points => {
	shape => 'candle2',
	color => [1.0, 0.2, 0.0],
	inner_color => undef,
	outer_color => undef,
	width => 0.5,
	inner_width => undef,
	outer_width => undef,
    },
    layout => {
	spacing => 0,
	top_margin => 3,
	right_margin => 15,
    },
    y_axis => {
	color => 0.5,
	heavy_color => undef,
	mid_color => undef,
	light_color => undef,
	heavy_width => 0.75,
	mid_width => 0.5,
	light_width => 0.25,
	title => undef,
	mark_min => 0.5,
	mark_max => 6,
	label_gap => 30,
	si_shift => undef,
    },
    ## Graph internal fields
    # lines    => {},
    # lineord  => [],
    # gmin            logical min by gtype
    # gmax            logical max by gtype
    # pgp             PostScript::Graph::Paper
    # name            user name of graph
};
    
=head1 NAME

Finance::Shares::Chart - construct shares graph

=head1 SYNOPSIS

    use Finance::Shares::Chart;

    my $fsc = new Finance::Shares::Chart( <options> );
    $fsc->add_data($data);
    $fsc->add_line($line);
    $fsc->build();
    $fsc->output($filename, $dir);

    $fsc->add_graph($name, $opt_hash);
    $fsc->set_period($start, $end);
    my $data = $fsc->data();

=head1 DESCRIPTION

This module provides the output for L<Finance::Shares::Model>.  It builds a series of graphs on a single page, with a key panel
indicating the role of any lines added.  A Finance::Shares::data object may be declared, which provides stock price quotes and volume
information.  Any number of Finance::Shares::Line objects may be displayed as well.  These are normally generated from
Finance::Shares::Function objects (See L<Finance::Shares::Function> for details).

There are four types of graphs.  Each type may appear as often as you wish (or not at all), but the first of each
type gets used if none other is specified.

=over 10

=item price

Price data can be displayed using normal open-close-high-low marks, Japanese candles, or just the closing
positions for each day.  The Y axis is scaled for prices.

=item volume

Volume bars are displayed on this graph whose Y axis is typically scaled in millions.

=item analysis

There would typically be more than one 'analysis' graph on a chart.  The Y axis is usually scaled to show price
movements which may be negative as well as positive.

=item level

Several of the available functions compare two other lines or signal whether conditions are true or false.  Their
results would be shown on a 'level' graph.  The Y axis is often scaled 0 to 100%.

=back

As there is only one Key panel shared by all graphs, each line is typically displayed in a different colour by
default.  Like almost everything else, this behaviour is configurable.

All error, log and debug messages are controlled by Log::Agent.  By default this does the expected thing, but it
does mean they may be routed differently as required.  See L<Log::Agent> for details.

=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;

    ## Defaults
    # only these keys will be accepted
    my $o = {
	verbose => 1,
	id => '',
	model => undef,
	hidden => 0,
	background => $background,
	bgnd_outline => 0,
	dpi => 300,
	directory => '~',
	glyph_ratio => $glyph_ratio,
	heading => '',
	page => undef,
	smallest => 3,
	sequence => undef,
	stock => '',
	show_breaks => 1,
	periods_before => undef,
	by => 'weekdays',
	start => undef,
	end => undef,
	periods_after => undef,
	file => {
	    paper => 'A4',
	    width => undef,
	    height => undef,
	    landscape => 1,
	    eps => 0,
	    png => 0,
	    gs => 'gs',
	    left => 36,
	    right => 36,
	    top => 36,
	    bottom => 36,
	    clipping => 0,
	    clip_command => 'clip',
	    dir => undef,
	    headings => 1,
	    reencode => '',
	    debug => 0,
	    errors => 1,
	    errx => 72,
	    erry => 72,
	},
	heading_font => 'Times-Bold',
	heading_size => 14,
	heading_color => 0,
	normal_font => 'Helvetica',
	normal_size => 10,
	normal_color => 0,
	key => {
	    background => $background,
	    outline_color => 0,
	    outline_width => 1,
	    title => 'Key',
	    title_font => 'Helvetica-Bold',
	    title_size => 12,
	    title_color => 0,
	    text_font => 'Helvetica',
	    text_size => 10,
	    text_color => 0,
	    spacing => 4,
	    vert_spacing => undef,
	    horz_spacing => undef,
	    icon_width => undef,
	    icon_height => undef,
	    text_width => undef,
	    glyph_ratio => $glyph_ratio,
	},
	x_axis => {
	    show_lines => 1,
	    changes_only => 1,
	    show_weekday => undef,
	    show_day => undef,
	    show_month => undef,
	    show_year => undef,
	    color => 0.5,
	    heavy_color => undef,
	    mid_color => undef,
	    light_color => undef,
	    heavy_width => 0.75,
	    mid_width => 0.5,
	    light_width => 0.25,
	    mark_min => 0.5,
	    mark_max => 6,
	},
	graphs => [],

	## Internal fields
	# quotes            Finance::Shares::data
	# gpapers   => {},  user name => settings ('graphs' is a user option arrayref)
	# gpaperord => [],  user names in order
	# labels   => [],   date labels
	# dlabels  => [],   dummy date labels
	# lblspc            vspace required for date labels
	# pgk               PostScript::Graph::Key
	# pgsq		    PostScript::Graph::Sequence
	# kstyles  => {},   Styles to show on Key
	# nlabels           Number of date labels
	# totalpc           Sum of graph percents
	# dgpaper           {gpapers} hash with date labels
	# pxmin...pymax     page boundaries
    };

    ## Setup
    bless( $o, $class );

    my $opts = {};
    if (@_ == 1) { $opts = $_[0]; } else { %$opts = @_; }
    $o->add_parameters(	$opts, $o, '' );
    
    ## Finish
    out($o, 4, "new $class");
    return $o;
}

=head1 new( options )

<options> must be a hash ref or a list of hash keys and values.  There are a lot of them - up to 250 or more.
Many are just listed here.  See the indicated man pages for full details.  The options fit within a hash tree
structure like the following.

    my $fsc = new Finance::Shares::Chart(
	background => [0.9, 0.95, 0.95],
	stock      => 'MSFT',
	period => {
	    start  => '2003-01-01',
	    by     => 'weeks',
	},
	graphs => [
	    MACD => {
		percent => 40,
	    },
	    Tests => {
		gtype => 'level',
		show_dates => 1,
	    },
	],
    );

Colours can be a decimal from 0 (black) to 1 (brightest), or a triple within an array ref when each decimal
represents the brightness of red, green and blue.  Any measurements are in PostScript units (1/72"), so think
point sizes.
    
=head2 Top level options

=over 8

=item verbose

Controls the amount of feedback provided

    0	silent
    1	errors only (default)
    2	slghtly more informative
    3+	debugging

=item iname

A unique name assigned by L<Finance::Shares::Model>.  It identifies the chart and its associated data (if any).

=item background

The background colour for all the graphs.  This can be a shade of grey (0.0 for black, 1.0 for brightest) or
an array ref holding similar decimals for red, green and blue, e.g. [ 0.6, 0.4, 0 ] for a red-orange.  (Default:
1.0)

=item bgnd_outline

By default the price and volume marks are drawn with a contrasting outline.  Setting this to 1 makes this outline
the same colour as the background.  (Default: 0)

=item dpi

One of the advantages of PostScript output is that it can make the best use of each medium.  Setting this to 72
produces output suitable for most computer monitors.  Use a higher figure for hard copy, depending on you
printer's capabilities.  (Default: 300)

=item directory

Optional directory prepended to the output file name.

=item glyph_ratio

Generating PostScript is a one-way process.  It is not possible to find out how much space will be taken up by
a string using a proportional spaced font, so guesses are made.  This allows that guess to be fine tuned.
(Default: 0.44)

=item heading

Appears at the top of the page.  Defaults to something suitable.

=item page

An optional string used as the PostScript page 'number'.  Although this may be anything many programs expect this
to be short like a page number, with no spaces.

=item smallest

The underlying PostScript::Graph::Paper module will sometimes generate more subdivisions and axis lines than
needed, especially at high resolutions.  C<smallest> provides some control over this for the Y axes.  It specifies
the size of the smallest gap between lines; giving a larger number means fewer lines.  The default produces 3 dots
at the resolution given to B<dots_per_inch>.

Note that the only way to control the line density on the X axis is to plot fewer dates.  One way of doing this is
to set the Finance::Shares::Sample contructor option C<by> to 'weeks' or 'months'.

=item sequence

An internal L<PostScript::Graph::Sequence> controls the different colours given to each line displayed.  Assigning
your own here gives you more control of how the lines appear.  Not that it is possible to override this behaviour
completely by specifying C<auto => 'none'> within each line style hash.  See L<PostScript::Graph::Style>.

=item stock

This would be a code indicating the particular stock being displayed.  However, it could be anything as it is only
used in constructing the default heading.

=item show_breaks

A value of 1 means that any undefined values show a break in the line, otherwise the line is continuous.
(Default: 0)

=back

=head3 period

The chart displays dates in a given range at a particular frequency - days, months etc.  It does not show all the
dates in the associated Finance::Shares::data object, as a certain lead time is often required to establish reliable
calculations.  The chart may also have an unfilled area after the end of the data to allow for a little
extrapolation.

These details are given within a C<period> sub-hash, which may have the following fields.

=over 8

=item start

The first date to be displayed.  It should be in YYYY-MM-DD format.

=item end

The last date on the chart.  Again, in YYYY-MM-DD format.

=item by

Determines how the intervening dates are counted.  Suitable values are

    quotes	weekdays
    days	weeks
    months

=back

=head3 file

This can be either a PostScript::File object or a hash ref holding parameters suitable for creating one.  The
default is to set up a landscape A4 page with half inch margins.  The hash ref may contain the following keys.
See L<PostScript::File> for details.

    paper	width
    height	landscape
    eps		dir
    png		gs
    left	right
    top		bottom
    clipping	clip_command
    headings	reencode
    debug	errors
    errx	erry
    
=head3 heading_font

A sub-hash controlling how the heading appears.  Recognized keys are:

=over 8

=item font

The font family name which should be one of the following.  (Default: 'Times-Bold')

    Courier
    Courier-Bold
    Courier-BoldOblique
    Courier-Oblique
    Helvetica
    Helvetica-Bold
    Helvetica-BoldOblique
    Helvetica-Oblique
    Times-Roman
    Times-Bold
    Times-BoldItalic
    Times-Italic
    Symbol

=item size

Point size to use.  (Default: 14)

=item color

The normal colour format: either a grey value or an array ref holding [<red>,<green>,<blue>].  (Default: 1.0)

=back

=head3 normal_font

This controls the font used to label the graphs.  The defaults are different ('Helvetica', 10pt) but the keys are
the same as for B<heading_font>.

=head3 key

This sub-hash controls the appearance of the Key panel.  See L<PostScript::Graph::Key> for details of these
possible entries.

    background	    title
    outline_color   outline_width
    title_font	    text_font
    spacing	    glyph_ratio
    vert_spacing    horz_spacing
    icon_width	    icon_height
    text_width
   
=head3 x_axis

The dates axis is controlled by this sub-hash.  The C<show_> options largely refer to how the date labels are built
up.  C<changes_only> controls whether the full label is shown (0) or only those parts that have changed (1).
Other options are explained in L<PostScript::Graph::Paper>.

    show_lines	    changes_only
    show_weekday    show_day
    show_month	    show_year
    mark_min	    mark_max
    color	    heavy_color
    mid_color	    light_color
    heavy_width	    mid_width
    light_width

=head3 graphs

This is an exception.  Where all the other headings describe hash refs, this is an array ref.  The array lists
descriptions for each of the graphs to be shown on the page.  Each graph description is a hash ref keyed by the
graph's title.

    graphs => [
	'Stock Prices' => {
		gtype => 'price',
		...
	    },
	'Trading Volumes' => {
		gtype => 'volume',
		...
	    },
	'Momentum' => {
		gtype => 'analysis',
		...
	    },
	'On-Balance Volume' => {
		gtype => 'analysis',
		...
	    },
	...
    ],

=head2 Graph options

Each graph hash ref may include any of the following values or sub-hashes.

=over 8

=item percent

This is the proportion of space allocated to the graph.  Specifying 0 hides it.  It is not a strict percentage in
that they don't all have to add up to 100, but it does give an idea of the sort of numbers to put here.  There may
be problems if the value is less than 10, or so small the graph cannot physically be drawn in the space.  

Some graphs will become visible automatically (provided their percent is not 0) if data or lines should be shown
there.  They take a default value of 20.

=item gtype

Identifies the type of Y axis to use.  Must be one of

    price	volume
    analysis	level

=item show_dates

True if the dates axis is to be shown under this chart.  By default the dates are placed under the first graph
that hasn't specified show_dates => 0.
   
=back

=head3 bars

Only appropriate for the C<volume> type graph, this sub-hash specifies how the volume bars look.  See
L<PostScript::Graph::Style>.

    color	    width
    inner_color	    outer_color
    inner_width	    outer_width

=head3 points

Only appropriate for the C<price> type graph, this sub-hash specifies how the price marks look.  Values for
C<shape> are as follows and NOT as described in L<PostScript::Graph::Style>.

    stock   stock2
    candle  candle2
    close   close2
    
The other options are as B<bars>.

=head3 layout

See L<PostScript::Graph::Paper> for details.

    spacing
    top_margin
    right_margin
    
=head3 y_axis

See L<PostScript::Graph::Paper> for details.

    title	    color
    heavy_color	    mid_color
    light_color	    heavy_width
    mid_width	    light_width
    mark_min	    mark_max
    label_gap	    si_shift

=cut

sub add_data {
    my ($o, $data) = @_;
    return unless ref($data) and $data->isa('Finance::Shares::data');
    out($o, 5, "Chart::add_data()");
    $o->{quotes} = $data;
    
    # ensure there are graphs to display data on
    $o->graph_for($data->line('close'));
    $o->graph_for($data->line('volume'));
}

=head2 add_data( data )

Declare the stock quote data associated with this chart - there should only be one.  C<data> must be a L<Finance::Shares::data>
object.

=cut

sub add_line {
    my ($o, $line) = @_;
    logdie("$line should be a Line object") unless ref($line) eq 'Finance::Shares::Line';
    my $gh = $o->graph_for($line);
    my $lname = $line->name();
    unless ($gh->{lines}{$lname}) {
	$gh->{lines}{$lname} = $line;
	push @{$gh->{lineord}}, $lname;
	out($o, 5, "Chart::add_line: '$lname'");
    }
}
# may be called multiple times checking same line is added

=head2 add_line( line )

Register a line with this chart.  C<line> should be a Finance::Shares::Line derived object.  It's graph is determined from its
optional {graph} or mandatory {gtype} fields.

=cut

sub build {
    my $o = shift;
    out($o, 5, "Chart::build '$o->{id}'");
    $o->{built}++, return if $o->{hidden};
    out_indent(1);
    
    ## Preparation
    $o->ensure_period();
    
    logdie("Chart has no PostScript::File") unless ref($o->{file}) eq 'PostScript::File';
    $o->{file}->set_page_label( $o->{page} ) if defined $o->{page};

    PostScript::Graph::Paper->ps_functions( $o->{file} );
    PostScript::Graph::Key->ps_functions( $o->{file} );
    PostScript::Graph::XY->ps_functions( $o->{file} );
    PostScript::Graph::Style->ps_functions( $o->{file} );
    Finance::Shares::Chart->ps_functions( $o->{file} );

    $o->{file}->add_to_page( <<END_INIT );
	gpaperdict begin
	gstyledict begin
	xychartdict begin
	gstockdict begin
END_INIT

    ## Create graphs
    $o->prepare_labels();
    my $keys    = $o->prepare_graphs();
    my @pagebox = $o->{file}->get_page_bounding_box();
    $o->{pxmin} = $pagebox[0];
    $o->{pymin} = $pagebox[1];
    $o->{pxmax} = $pagebox[2];
    $o->{pymax} = $pagebox[3];
    $o->{pgk}   = $o->create_key( $keys, \@pagebox ) if @$keys;
    my $gpaper  = $o->create_graphs( \@pagebox );
    
    ## Draw graphs
    $o->draw_grids();
    if (@$keys) {
	# kludge to get key by side of all charts
	$gpaper->{ch}{gy1}    = $pagebox[3];
	$gpaper->{ch}{bottom} = $pagebox[1];
	$o->{pgk}->build_key($gpaper);
    }
    $o->draw_lines();
    my $keyorder = $o->reorder_keys();
    $o->draw_keys($keyorder);
    
    ## Finish
    $o->{file}->add_to_page( "end end end end\n" );
    $o->{built}++;
    
    out_indent(-1);
}

=head2 build( )

Once the resources are gathered, this method puts them all together.  The chart is built in PostScript.
If no PostScript::File object was given to the constructor one is created for this chart, otherwise the chart is
written to the current page.

=cut

sub output {
    my ($o, $filename, $directory) = @_;
    $directory = $o->{directory} unless defined $directory;
    $o->build() unless $o->{built};
    $o->{file}->output($filename, $directory) unless $o->{hidden};
}

=head2 output( [filename [, directory]] )

The graphs are constructed and written out to a PostScript file.  A suitable suffix (.ps, .epsi or .epsf) will be
appended to the file name.

If no filename is given, the PostScript text is returned.  This makes handling CGI requests easier.

=cut


=head1 ACCESS METHODS

=cut

sub name {
    return $_[0]->{id};
}

=head2 name( )

Returns the canonical name for this chart.

=cut

sub data {
    my $o = shift;
    return $o->{quotes};
}

=head2 data( )

Return the L<Finance::Shares::data> object holding the stock quotes for this chart.

=cut

sub graph_for {
    my ($o, $line) = @_;
    my $gname = $line->{graph} || $line->{gtype} || 'price';
    my $gh;
    if ($o->{gpapers}{$gname}) {
	$gh = $o->{gpapers}{$gname};
    } elsif (not $line->{graph}) {
	# use the first suitable graph
	foreach my $name (@{$o->{gpaperord}}) {
	    my $g = $o->{gpapers}{$name};
	    $gh = $g, last if $g->{gtype} eq $line->{gtype};
	}
    }
    unless ($gh) {
	# line starts a new graph
	out($o, 7, "Chart: new graph '$gname' for line '" . $line->name . "'");
	my $params = {
	    gtype => $line->{gtype},
	    graph => $line->{graph},
	};
	$gh = $o->add_graph($gname, $params);
    }
    out($o, 7, "Chart::graph_for(" . $line->name . ") = $gh->{name}");
    return $gh;
}

=head2 graph_for( line )

The most reliable way of determining which graph a particular L<Finance::Shares::Line> object will appear on.  A new graph is
created if no existing graph is suitable.  C<line> must have at least a {gtype} field and optionally a {graph}
field holding a graph name.

=cut

sub model {
    return $_[0]->{model};
}

sub set_period {
    my ($o, $start, $end) = @_;
    $o->{start} = $start;
    $o->{end}   = $end;
}

=head2 set_period( )

Used by the associated L<Finance::Shares::data> object to ensure the dates used in the default title are correct.

=cut

sub hidden {
    return $_[0]->{hidden};
}

=head2 hidden( )

Returns true if the chart is not to be displayed.

=cut

### SUPPORT METHODS

sub add_parameters {
    my ($o, $opt, $ok, $entry ) = @_;
    return unless defined $opt;
    out($o, 7, "Chart::add_parameters($entry)");
    out_indent(1);
    
    if (ref($ok) eq 'ARRAY') {
	# graph descriptions
	logerr("array ref expected, found $opt"), return unless ref($opt) eq 'ARRAY';
	logerr("odd number of elements in array"), return if (@$opt % 2);
	for( my $i = 0; $i <= $#$opt; $i += 2 ) {
	    my $key = $opt->[$i];
	    my $value = $opt->[$i+1];
	    logerr("'$key' value should be a hash ref"), return unless ref($value) eq 'HASH';
	    my $gh = $o->add_graph($key, $value);
	    push @$ok, $gh;
	    $o->process_hash( $value, deep_copy($graph_options), "graph $key" );
	}
    } elsif (ref $ok) {
	$o->process_hash($opt, $ok, $entry);
    } else {
	logerr("Cannot assign $entry");
    }
    out_indent(-1);
}
## add_parameters( given, acceptable )
#
# Over-write the acceptable settings with the given ones if presented at the right position.
# Called recursively throughout tree.  Where any graphs are defined, the whole $graph_options tree is copied in at
# that point.


sub add_graph {
    my ($o, $name, $params) = @_;
    out($o, 7, "Chart::add_graph($name)");
    out_indent(1);
    
    my $gh = deep_copy $graph_options;
    $gh->{name} = $name;
    $o->add_parameters( $params, $gh, "new graph '$name'" );
    delete $gh->{points} unless $gh->{gtype} =~ /^price/;
    delete $gh->{bars}   unless $gh->{gtype} =~ /^volume/;

    $o->{gpaperord} = [] unless defined $o->{gpaperord};
    push @{$o->{gpaperord}}, $name;
    $o->{gpapers}{$name} = $gh;

    $gh->{gmin}    = $highest_int;
    $gh->{gmax}    = $lowest_int;
    $gh->{lineord} = [];    # line names
    $gh->{lines}   = {};    # line name => object

    out_indent(-1);
    return $gh;
}

sub ensure_period {
    my $o = shift;
    if ($o->{quotes}) {
	my $d = $o->{quotes};
	$o->{stock} = $d->{stock} if $d->{stock} and not $o->{stock};
	$o->{start} = $d->start unless defined $o->{start};
	$o->{by}   = $d->{by}  unless defined $o->{by};
	$o->{end}   = $d->{end} unless defined $o->{end};
    } else {    
	my $by = $o->{by} || '';
	my $ok = 0;
	foreach my $period (qw(quotes weekdays days weeks months)) {
	    $ok = 1, last if $by eq $period;
	}
	$o->{by} = 'weekdays' unless $ok;
	$o->{end} = today_as_string() unless is_date $o->{end}; 
	$o->{start} = decrement_date($o->{end}, 60, $o->{by}) unless is_date $o->{start};
    }
     out($o, 5, "Chart::ensure_period '$o->{stock}' $o->{by} from $o->{start} to $o->{end}");
}

sub process_hash {
    my ($o, $opt, $ok, $entry ) = @_;
    return unless defined $opt;
    foreach my $key (keys %$ok) {
	my $acceptable = $ok->{$key};
	my $given = $opt->{$key};
	my $ref = ref($given);
	if ($key eq 'graphs' or $ref eq 'HASH') {
	    $o->add_parameters( $given, $acceptable, $key );
	} else {
	    # scalar or object
	    if (defined $given) {
		$ok->{$key} = $given;
		out($o, 7, "$key = $given");
	    }
	}
    }
}

sub labels_defaults {
    my $o = shift;
    
    my $dtype = $o->{by};
    my ($dsdow, $dsday, $dsmonth, $dsyear, $dsall);
    CASE: {
	if ($dtype eq 'weeks') {
	    ($dsdow, $dsday, $dsmonth, $dsyear) = (0, 1, 1, 0);
	    last CASE;
	}
	if ($dtype eq 'months') {
	    ($dsdow, $dsday, $dsmonth, $dsyear) = (0, 0, 1, 1);
	    last CASE;
	}
	# ($dtype eq 'data' or 'days')
	    ($dsdow, $dsday, $dsmonth, $dsyear) = (0, 1, 1, 0);
    }
    my $x = $o->{x_axis};
    $x->{show_weekday} = $dsdow   unless defined($x->{show_weekday});
    $x->{show_day}     = $dsday   unless defined($x->{show_day});
    $x->{show_month}   = $dsmonth unless defined($x->{show_month});
    $x->{show_year}    = $dsyear  unless defined($x->{show_year});

    return;
}

sub prepare_labels {
    my ($o, $skip) = @_;
    out($o, 5, "Chart::prepare_labels()");
    my $d = $o->{quotes};
    unless ($d and @{$d->dates}) {
	$o->{labels} = [$o->{start} || '', $o->{end} || ''];
	$o->{dlabels}= [''];
	$o->{lblspc} = $o->{x_axis}{mark_max} + $o->{normal_size};
	return;
    }
 
    $o->labels_defaults();

    ## Prepare for label creation
    my @days   = qw(- Mon Tue Wed Thu Fri Sat Sun);
    my @months = qw(- Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my (@labels, @dlabels);
    my $labellength = 0;
    
    my $ldow = 0;
    my ($lday, $lmonth, $lyear) = (0, 0, 0);
    my $skip_count = 0;
    
    my $x      = $o->{x_axis};
    my $dsall  = not $x->{changes_only};
    
    ## Create labels and calc min/max values
    for my $date (@{$d->dates}) {
	next unless $date ge $d->{start};
	my ($year, $month, $day) = ymd_from_string($date);
	my $dow = day_of_week($year, $month, $day);
	my $label = '';
	$label .= $days[$dow]     . ' ' if $x->{show_weekday} and ($dsall or ($dow != $ldow));
	$label .= $day            . ' ' if $x->{show_day}     and ($dsall or ($day != $lday));
	$label .= $months[$month] . ' ' if $x->{show_month}   and ($dsall or ($month != $lmonth));
	$label .= $year		  . ' ' if $x->{show_year}    and ($dsall or ($year != $lyear));
	$label =~ s/\s+$//;
	if ($skip) {
	    if ($skip_count) {
		$skip_count--;
		push @labels, '()';
		push @dlabels, '()';
	    } else {
		$skip_count = $skip;
		push @labels,  "($label)";
		push @dlabels, '( )';
		$ldow=$dow; $lday=$day; $lmonth=$month; $lyear=$year;
	    }
	} else {
	    push @labels,  $label;
	    push @dlabels, ' ';
	    $ldow=$dow; $lday=$day; $lmonth=$month; $lyear=$year;
	}
	$labellength = length($label) if (length($label) > $labellength);
    }
    
    ## Record results
    $o->{labels} = [ @labels ];
    $o->{dlabels}= [ @dlabels ];
    $o->{lblspc} = $o->{x_axis}{mark_max} + (1 + $labellength * $o->{glyph_ratio}) * $o->{normal_size};
}
# If $skip > 0 the labels are being adjusted, so they must be in PostScript format, i.e. '(...)'

sub create_sequence {
    my $o = shift;
    out($o, 5, "Chart::create_sequence()");
    my $seq = $o->{sequence};
    
    unless (ref($seq) eq 'PostScript::Graph::Sequence') {
	$seq = new PostScript::Graph::Sequence;
	$seq->setup('color', [
	    [0,1,0],	    # bright green
	    [0,0.6,0],	    # dark green
	    [0,0.6,0.6],    # turquoise
	    [0,1,1],	    # cyan
	    [0,0,1],	    # bright blue
	    [0.6,0,0.6],    # purple
	    [1, 0, 1],	    # mauve
	    [0.6,0,0],	    # dark red
	    [1,0,0],	    # bright red
	    [1,0.6,0],      # orange
	    [1,1,0],	    # yellow
	    [0.6,0.6,0],    # leaf green
	]);
	$seq->auto(qw(color dashes));
    }
    
    $o->{pgsq} = $seq;
}

sub create_style {
    my ($o, $line) = @_;
    my $h = $line->{style};
    out($o, 5, "Chart::create_style() for ". $line->name);
    return $h if ref($h) eq 'PostScript::Graph::Style';
    $h = $default_line_style unless $h;
    my $none = (defined($h->{line}) or defined($h->{point}) or defined($h->{bar}));
    $h->{line} = {} unless $none;
    $h->{point} = {} unless $none;	# show lines & points if nothing chosen
    $h->{sequence} = $o->{pgsq} unless defined $h->{sequence};
    $h->{label} = $line->name;
    return new PostScript::Graph::Style( $h );
}

sub create_key {
    my ($o, $keys, $pagebox) = @_;
    out($o, 5, "Chart::create_key()");

    my $height = $pagebox->[3] - $pagebox->[1];
    my $maxsize = $o->{normal_size};
    my $lwidth  = 3;
    my $maxlen  = 0;
    foreach my $k (@$keys) {
	my $len	 = length $k;
	$maxlen	 = $len if ($len > $maxlen);
    }

    my $k = $o->{key};
    $k->{max_height}  = $height;
    $k->{item_labels} = $keys;
    $k->{title}	      = 'Key' unless defined $k->{title};
    $k->{icon_width}  = $maxsize * 3 unless defined $k->{icon_width};

    my $max_width     = 0.2 * ($pagebox->[2] - $pagebox->[0]);
    $max_width       -= ($k->{icon_width} - 3 * $lwidth);
    my $tsize         = defined($k->{text_size}) ? $k->{text_size} : 10;
    unless (defined $k->{text_width}) {
	$k->{text_width}  = $maxlen * $tsize * $k->{glyph_ratio};
	$k->{text_width}  = $max_width if $k->{text_width} > $max_width;
    }
    
    $k->{icon_height} = $maxsize * 1.2 unless defined $k->{icon_height};
    $k->{spacing}     = $lwidth unless defined $k->{spacing};
    $k->{file}	      = $o->{file};
    
    my $f = {
	font  => $k->{title_font},
	size  => $k->{title_size},
	color => $k->{title_color},
    };
    $k->{title_font} = $f;
    $f = {
	font  => $k->{text_font},
	size  => $k->{text_size},
	color => $k->{text_color},
    };
    $k->{text_font} = $f;

    return new PostScript::Graph::Key( $k );
}

sub prepare_graphs {
    my $o = shift;
    out($o, 5, "Chart::prepare_graphs()");
    $o->create_sequence;
    
    my @keys;
    my %styles;
    my $nlabels = 0;
    foreach my $gname (@{$o->{gpaperord}}) {
	my $g = $o->{gpapers}{$gname};
	$g->{name}    = $gname;
	$g->{file}    = $o->{file};

	$o->graph_range($g);
	next unless $g->{visible};
	foreach my $lname (@{$g->{lineord}}) {
	    my $l = $g->{lines}{$lname};
	    if ($l->{shown}) {
		my $pstyle = $o->create_style($l);
		unless ($styles{$pstyle}) {	    # ensure appears in Key only once
		    push @keys, $l->{key} || '';
		    $l->{style} = $pstyle;
		    $styles{$pstyle} = $l;
		}
	    }
	}
	$nlabels++ if $g->{show_dates};
    }

    $o->ensure_graphs;
    
    $o->{kstyles} = \%styles;
    $o->{nlabels} = $nlabels;
    return \@keys;
}

sub ensure_graphs {
    my ($o, $given) = @_;
    
    my $totalpc = 0;
    my (@gpaperord, %gpapers);
    foreach my $gname (@{$o->{gpaperord}}) {
	my $g = $o->{gpapers}{$gname};
	$o->graph_set_range($g);
	$totalpc += ($g->{percent} || 20) if $g->{visible};
	$gpapers{$gname} = $g;
	push @gpaperord, $gname;
    }
 
    unless ($totalpc) {
	my $gname = 'default';
	my $g = $o->add_graph($gname, { gtype => 'price' });
	$o->graph_set_visible($g);
	$o->graph_set_range($g);
	$totalpc += $g->{percent};
	$gpapers{$gname} = $g;
	push @gpaperord, $gname;
    }
    
    $o->{gpaperord} = \@gpaperord;
    $o->{gpapers}   = \%gpapers;
    $o->{totalpc}   = $totalpc;
}


sub create_graphs {
    my ($o, $pagebox) = @_;
    out($o, 5, "Chart::create_graphs()");
    
    my $heading = $o->{heading_size} - 5;
    my $top     = $pagebox->[3]-1;
    my $bottom  = $pagebox->[1]+1;
    my $default = ($o->{nlabels} == 0);	    # {show_dates} is added to first graph if none specified
    my $unitpc  = ($top - $bottom - $heading - ($o->{nlabels}+$default)*$o->{lblspc})/$o->{totalpc};
    my $gpaper;

    foreach my $gname (@{$o->{gpaperord}}) {
	my $g = $o->{gpapers}{$gname};
	next unless $g->{visible};
	if ($heading) {
	    $g->{show_dates} = 1 if $default;
	    $o->{dgpaper} = $g;
	}
	## calculate height
	my $height = $g->{percent} * $unitpc;
	$height += $o->{lblspc} if $g->{show_dates};
	$height += $heading;
	
	## layout options
	my $l = $g->{layout};
	$l->{background} = $o->{background};
	$l->{top_edge} = $top;
	$top = $l->{bottom_edge} = $top - $height;
	$l->{key_width} = $o->{pgk} ? $o->{pgk}->width() : 0;
	$l->{top_margin} = 3 unless defined $l->{top_margin};;
	$l->{no_drawing} = 1;	# delay drawing until labels have been checked
	if ($heading) {
	    my $stock = ($o->{stock} eq 'default' ? '' : $o->{stock});
	    $l->{heading} = $o->{heading} ? $o->{heading} : 
		    "$stock $o->{by} from $o->{start} to $o->{end}";
	    $l->{heading_height} = $l->{heading_font_size} unless defined $l->{heading_height};
	} else {
	    $l->{heading_height} = 5 unless defined $l->{heading_height};
	}
	
	## x_axis options
	my $x = $g->{x_axis} = deep_copy $o->{x_axis};
	$x->{draw_fn} = 'xdrawstock';
	$x->{offset} = 1;
	$x->{sub_divisions} = 2;
	$x->{center} = 0;
	if ($g->{show_dates}) {
	    $x->{labels} = $o->{labels};
	    $x->{glyph_ratio} = $o->{glyph_ratio};
	} else {
	    $x->{labels} = $o->{dlabels};
	    $x->{mark_max} = 0;
	}

	## y_axis options
	my $y          = $g->{y_axis};
	$y->{low}      = $g->{gmin};
	$y->{high}     = $g->{gmax};
	$y->{title}    = $g->{name};
	$y->{smallest} = $o->{smallest} unless defined $y->{smallest};
	$y->{si_shift} = 0 if $g->{gtype} eq 'price' and not defined $y->{si_shift};
	
	## create graph paper
	$g->{file} = $o->{file};
	#warn "gpaper opts...\n", show_deep($g);
	$g->{pgp} = new PostScript::Graph::Paper( $g );
	my $report = '(top=' . int($l->{top_edge}) .', btm=' . int($l->{bottom_edge}) . ')'
	    . ($heading ? ' heading' : '') . ($g->{show_dates} ? ' dates' : '');
	out($o, 4, "new Paper for $g->{name} $report");
	
	$gpaper = $g->{pgp} unless $gpaper;
	$heading = 0;
    }

    return $gpaper;
}

sub draw_grids {
    my $o = shift;
    out($o, 5, "Chart::draw_grids()");
    out_indent(1);

    ## fit labels
    my $pgp = $o->{dgpaper}{pgp};
    return unless $pgp;
    my $space_reqd  = @{$o->{labels}} * $pgp->x_axis_font_size();
    my $graph_width = $pgp->x_axis_width();
    my $skip = int($space_reqd/$graph_width);
    if ($space_reqd > $graph_width) {
	$o->prepare_labels($skip);
	foreach my $gname (@{$o->{gpaperord}}) {
	    my $g = $o->{gpapers}{$gname};
	    next unless $g->{percent};
	    my $pgp = $g->{pgp};
	    if ($pgp) {
		if ($g->{show_dates}) {
		    $pgp->x_axis_labels( $o->{labels} );
		} else {
		    $pgp->x_axis_labels( $o->{dlabels} );
		}
		$pgp->draw_scales();
	    }
	}
    } else {
	foreach my $gname (@{$o->{gpaperord}}) {
	    my $g = $o->{gpapers}{$gname};
	    my $pgp = $g->{pgp};
	    $pgp->draw_scales() if $pgp;
	}
    }

    out_indent(-1);
}
# adjust date labels to fit
# Avoids date labels overwriting each other when there are too many

sub draw_lines {
    my $o = shift;
    out($o, 5, "Chart::draw_lines()");
    out_indent(1);
    
    my $order = $lowest_int;
    foreach my $gname (@{$o->{gpaperord}}) {
	my $graph = $o->{gpapers}{$gname};
	$o->reorder_lines($graph);
	my $data_shown = 0;
	foreach my $lname (@{$graph->{lineord}}) {
	    my $line = $graph->{lines}{$lname};
	    my $z = $line->order();
	    if ($order < 0 and $z >= 0) {
		if ($graph->{gtype} eq 'price') {
		    $o->price_marks($graph);
		} elsif ($graph->{gtype} eq 'volume') {
		    $o->volume_marks($graph);
		}
		$data_shown = 1;
		$order = 0;
	    }
	    $o->draw_line($graph, $line);
	}
	unless ($data_shown) {
	    if ($graph->{gtype} eq 'price') {
		$o->price_marks($graph);
	    } elsif ($graph->{gtype} eq 'volume') {
		$o->volume_marks($graph);
	    }
	}
    }

    out_indent(-1);
}

sub price_marks {
    my ($o, $g) = @_;
    out($o, 5, "Chart::price_marks($g->{name})");
    
    my $pgp = $g->{pgp};
    return unless $pgp;
    my $sh = {
	auto => 'none',
	bgnd_outline => $o->{bgnd_outline},
	point => $g->{points}, 
    };
    my $pstyle = new PostScript::Graph::Style( $sh );
    $pstyle->background( $pgp->layout_background() );
    $pstyle->write( $o->{file} );
    my $d      = $o->{quotes};
    my $open   = $d->line('open')->{data};
    my $high   = $d->line('high')->{data};
    my $low    = $d->line('low')->{data};
    my $close  = $d->line('close')->{data};
    my $count  = 0;
    my $dates = $d->dates;
    for (my $i = 0; $i <= $#$dates; $i++) {
	my $x = $d->x_coord($i);
	next unless $x >= 0;
	my $psx = $pgp->px($x);
	if (defined $open->[$i]) {
	    my $oy = $pgp->py( $open->[$i] );
	    my $hy = $pgp->py( $high->[$i] );
	    my $ly = $pgp->py( $low->[$i] );
	    my $cy = $pgp->py( $close->[$i] );
	    $pgp->add_to_page("$psx $oy $ly $hy $cy ppshape\n");
	    $count++;
	}
    }
}

sub volume_marks {
    my ($o, $g) = @_;
    out($o, 5, "Chart::volume_marks($g->{name})");
    
    my $sh = {
	auto => 'none',
	bgnd_outline => $o->{bgnd_outline},
	bar  => $g->{bars},
    };
    my $pgp = $g->{pgp};
    return unless $pgp;
    my $vstyle = new PostScript::Graph::Style( $sh );
    $vstyle->background( $pgp->layout_background() );
    $vstyle->write( $o->{file} );
    my $d = $o->{quotes};
    my $volume = $d->line('volume')->{data};
    my $count = 0;
    my $dates = $d->dates;
    for (my $i = 0; $i <= $#$dates; $i++) {
	my $x = $d->x_coord($i);
	next unless $x >= 0;
	my $y = $volume->[$i];
	if (defined $y) {
	    my @bb     = $pgp->vertical_bar_area($x * 2, $y);
	    my $lwidth = $vstyle->bar_outer_width()/2;
	    $bb[0] += $lwidth;
	    $bb[1] += $lwidth;
	    $bb[2] -= $lwidth;
	    $bb[3] -= $lwidth;
	    $bb[3] = $bb[1] if ($bb[3] < $bb[1]);
	    $o->{file}->add_to_page( <<END_BAR );
		$bb[0] $bb[1] $bb[2] $bb[3] bocolor bowidth drawbox
		$bb[0] $bb[1] $bb[2] $bb[3] bicolor bicolor biwidth fillbox
END_BAR
	    $count++;
	}
    }
}

sub reorder_lines {
    my ($o, $graph) = @_;

    my @ordering;
    foreach my $lname (@{$graph->{lineord}}) {
	my $line = $graph->{lines}{$lname};
	push @ordering, [ $lname, $line->{order} ] unless $lname =~ /^data\//;
    };
    @{$graph->{lineord}} = map { $_->[0] } sort { $a->[1] <=> $b->[1] } @ordering;
}

sub draw_line {
    my ($o, $graph, $line) = @_;
    out($o, 5, "Chart::draw_line(" . $line->name . ')');

    return unless $line->npoints;
    my $pgp = $graph->{pgp};
    return unless $pgp;
    my $pgs = $line->{style};
    return unless $line->{shown} and ref($pgs) eq 'PostScript::Graph::Style';

    $pgs->background( $pgp->layout_background() );
    $pgs->write( $o->{file} );

    if ($pgs->use_bar) {
	$o->construct_bars($pgp, $pgs, $line);
    } else {
	$o->construct_points($pgp, $pgs, $line);
    }
}

sub construct_bars {
    my ($o, $pgp, $pgs, $line) = @_;
    
    my $q = $o->{quotes};
    my $d = $line->display;
    my $dates = $q->dates;
    for (my $i = 0; $i <= $#$dates; $i++) {
	my $y = $d->[$i];
	if (defined $y) {
	    my $x = $q->x_coord($i);
	    if (defined $x) {
		next unless $x >= 0;
		my @bb = $pgp->vertical_bar_area($x * 2, $y);
		my $lwidth = $pgs->bar_outer_width()/2;
		$bb[0] += $lwidth;
		$bb[1] += $lwidth;
		$bb[2] -= $lwidth;
		$bb[3] -= $lwidth;
		$o->{file}->add_to_page( <<END_BAR );
		    $bb[0] $bb[1] $bb[2] $bb[3] bocolor bowidth drawbox
		    $bb[0] $bb[1] $bb[2] $bb[3] bicolor bicolor biwidth fillbox
END_BAR
	    } else {
		my $date = $q->idx_to_date($i);
		logerr("UNKNOWN DATE: $date (y=$y) in line '" . $line->name . "'");
	    }
	}
    }
}

sub construct_points {
    my ($o, $pgp, $pgs, $line) = @_;
    
    my $q = $o->{quotes};
    my $showgaps = defined($o->{show_breaks}) ? $o->{show_breaks} : 0;
    my $points   = "";
    my $npoints  = -1;
    my $out_of_range = 0;
    my $d        = $line->display;
    my @sections;
    my $dates = $q->dates;
    for (my $i = 0; $i <= $#$dates; $i++) {
	my $y = $d->[$i];
	if (defined $y) {
	    #warn "$i, y=$y";
	    my $x = $q->x_coord($i);
	    if (defined $x) {
		next unless $x >= 0;
		my $px = $pgp->px($x + 0.5);
		my $py = $pgp->py($y);
		if ($py >= $o->{pymin} and $py <= $o->{pymax}) {
		    $points = "$px $py " . $points;
		    $npoints += 2;
		} else {
		    $out_of_range++;
		}
	    } else {
		my $date = $q->idx_to_date($i);
		logerr("UNKNOWN DATE: $date (y=$y) in line '" . $line->name . "'");
	    }
	} elsif ($showgaps and $points) {
	    push @sections, [ $points, $npoints ];
	    $points = '';
	    $npoints = -1;
	}
    }
    push @sections, [ $points, $npoints ] if $showgaps and $points;
    logerr("$out_of_range points out of range") if $out_of_range;

    ## prepare code for points and lines
    my $cmd;
    CASE: {
	if (    $pgs->use_point() and     $pgs->use_line()) {
	    $cmd = "xyboth";
	    last CASE;
	}
	if (    $pgs->use_point() and not $pgs->use_line()) {
	    $cmd = "xypoints";
	    last CASE;
	}
	if (not $pgs->use_point() and     $pgs->use_line()) {
	    $cmd = "xyline";
	    last CASE;
	}
	$cmd = "";
    }

    if ($showgaps) {
	foreach my $section (@sections) {
	    my ($points, $npoints) = @$section;
	    $o->{file}->add_to_page( "[ $points ] $npoints $cmd\n" ) if ($cmd);
	}
    } else {
	$o->{file}->add_to_page( "[ $points ] $npoints $cmd\n" ) if ($cmd);
    }
}

sub reorder_keys {
    my $o = shift;
    
    my @ordering;
    foreach my $ks (keys %{$o->{kstyles}}) {
	my $line = $o->{kstyles}{$ks};
	push @ordering, [ $ks, $line->{order} ];
    };
    @ordering = map { $_->[0] } sort { $a->[1] <=> $b->[1] } @ordering;
    return \@ordering;
}

sub draw_keys {
    my ($o, $order) = @_;
    foreach my $ks (@$order) {
	my $line = $o->{kstyles}{$ks};
	my $pgs = $line->{style};
	logerr("$pgs is not a Style"), next unless $pgs->isa('PostScript::Graph::Style');
	my $g = $o->graph_for($line);
	$pgs->background( $g->{pgp}->layout_background() );
	$pgs->write( $o->{file} );

	if ($pgs->use_bar) {
	    $o->key_bars($o->{pgk}, $pgs, $line);
	} else {
	    $o->key_points($o->{pgk}, $pgs, $line);
	}
    }
}

sub key_bars {
    my ($o, $pgk, $pgs, $line) = @_;
    $pgk->add_key_item( $line->{key}, <<END_KEY ) if defined $pgk;
    8 dict begin
	/cx kix0 kix1 add 2 div def
	/cy kiy0 kiy1 add 2 div def
	/dx kix1 kix0 sub 10 div def
	/dy kiy1 kiy0 sub 4 div def
	/x0 cx dx sub def
	/x1 cx dx add def
	/y0 cy dy sub def
	/y1 cy dy add def
	x0 y0 x1 y1 bocolor bowidth drawbox
	x0 y0 x1 y1 bicolor bicolor biwidth fillbox
    end
END_KEY
}

sub key_points {
    my ($o, $pgk, $pgs, $line) = @_;
    my ($keyouter, $keyinner, $keylines);
    CASE: {
	if (    $pgs->use_point() and     $pgs->use_line()) {
	    $keyouter = "point_outer kpx kpy draw1point";
	    $keylines = "[ kix0 kiy0 kix1 kiy1 ] 3 2 copy line_outer drawxyline line_inner drawxyline";
	    $keyinner = "point_inner kpx kpy draw1point";
	    last CASE;
	}
	if (    $pgs->use_point() and not $pgs->use_line()) {
	    $keyouter = "point_outer kpx kpy draw1point";
	    $keylines = "";
	    $keyinner = "point_inner kpx kpy draw1point";
	    last CASE;
	}
	if (not $pgs->use_point() and     $pgs->use_line()) {
	    $keyouter = "";
	    $keylines = "[ kix0 kiy0 kix1 kiy1 ] 3 2 copy line_outer drawxyline line_inner drawxyline";
	    $keyinner = "";
	    last CASE;
	}
	$keyouter = "";
	$keylines = "";
	$keyinner = "";
    }

    $pgk->add_key_item( $line->{key}, <<END_KEY ) if (defined $pgk);
	2 dict begin
	    /kpx kix0 kix1 add 2 div def
	    /kpy kiy0 kiy1 add 2 div def
	    $keyouter
	    $keylines
	    $keyinner
	end
END_KEY
}

sub graph_range {
    my ($o, $g) = @_;
    out($o, 6, "graph_range");
    $g->{visible} = not (defined($g->{percent}) and $g->{percent} == 0);

    my $q = $o->{quotes};
    if ($g->{gtype} eq 'price') {
	$o->graph_line_range($g, $q->line('open') );
	$o->graph_line_range($g, $q->line('high') );
	$o->graph_line_range($g, $q->line('low') );
	$o->graph_line_range($g, $q->line('close') );
    } elsif ($g->{gtype} eq 'volume') {
	$g->{gmin} = 0;
	$o->graph_line_range($g, $q->line('volume') );
	$g->{visible} = 0 unless $g->{gmax} > $lowest_int;
    }

    my $visible = $g->{visible};
    foreach my $lname (@{$g->{lineord}}) {
	my $l = $g->{lines}{$lname};
	$g->{visible} = 1 if ($l->{shown} and $l->npoints);
	$o->graph_line_range($g, $l) if $g->{visible} and not $l->for_scaling;
    }
    $o->graph_set_visible($g) if $visible != $g->{visible};
}
# Used by prepare_graphs() 
# and Finance::Shares::Line::scale() to ensure gmin and gmax are valid

sub graph_set_visible {
    my ($o, $g) = @_;

    $g->{percent} = 20 unless $g->{percent} and $g->{percent} > 20;
    $g->{visible} = 1;
}

sub graph_set_range {
    my ($o, $g) = @_;
    out($o, 6, "Chart::graph_set_range($g->{name}) min=$g->{gmin}, max=$g->{gmax}");
    unless ($g->{gmin} < $highest_int and $g->{gmax} > $lowest_int) {
	$g->{gmin} = 0;
	$g->{gmax} = 100;
    }
}

sub graph_line_range {
    my ($o, $g, $l) = @_;
    $g->{gmin} = $l->{lmin} if $l->{lmin} < $g->{gmin};
    $g->{gmax} = $l->{lmax} if $l->{lmax} > $g->{gmax};
    out($o, 6, "Chart::graph_line_range($g->{name}, ", $l->name, ") min=$g->{gmin}, max=$g->{gmax}");
}

sub axis_margin {
    my ($o, $gh) = @_;
    my $frac = 0.05;
    my $size = 5;
    my $pgp = $gh->{pgp};
    
    $o->graph_set_range($gh);
    if ($pgp) {
	my $pmax = $pgp->py( $gh->{gmax} );
	my $pmin = $pgp->py( $gh->{gmin} );
	my $pmargin = $frac * ($pmax - $pmin);
	$pmargin = ($pmargin > $size) ? $pmargin : $size;
	return $pgp->ly( $pmargin );
    } else {
	return $frac * ($gh->{gmax} - $gh->{gmin});
    }
}
# used by Finance::Shares::Line::value_range() to determine where 'min' and 'max' lines should go.

=head1 CLASS METHODS

The PostScript code is a class method so that it may be available to other classes that don't need a Stock object.

The useful functions in the 'gstockdict' dictionary draw a stock chart mark and a close mark in
either one or two colours.

    make_candle
    make_candle2
    make_stock
    make_stock2
    make_close
    make_close2

The all consume 5 numbers from the stack (even if they aren't all used):

    x yopen ylow yhigh yclose
   
=cut

sub ps_functions {
    my ($class, $ps) = @_;

    my $name = "StockChart";
    $ps->add_function( $name, <<END_FUNCTIONS ) unless ($ps->has_function($name));
	/gstockdict 20 dict def
	gstockdict begin

	/make_stock {
	    gsave point_inner stockmark grestore
	}bind def
	% x yopen ylow yhigh yclose => _

	/make_stock2 {
	    5 copy
	    gsave point_outer stockmark grestore
	    gsave point_inner stockmark grestore
	}bind def
	% x yopen ylow yhigh yclose => _
	
	/stockmark {
	    gpaperdict begin
	    gstockdict begin
		/yclose exch def
		/yhigh exch def
		/ylow exch def
		/yopen exch def
		/x exch xmarkgap add def
		/dx xmarkgap powidth 2 div sub def
		2 setlinecap
		newpath
		x dx sub yopen moveto
		x yopen lineto
		x ylow lineto
		0 0 rmoveto
		x yhigh lineto
		0 0 rmoveto
		x yclose lineto
		x dx add yclose lineto
		stroke
	    end end
	} bind def
	% x yopen ylow yhigh yclose => _

	/make_candle {
	    gsave point_inner candlemark grestore
	}bind def
	% x yopen ylow yhigh yclose => _

	/make_candle2 {
	    5 copy
	    gsave point_outer candlemark grestore
	    gsave point_inner candlefill grestore
	}bind def
	% x yopen ylow yhigh yclose => _
	
	/candlemark {
	    gpaperdict begin
	    gstockdict begin
		/yclose exch def
		/yhigh exch def
		/ylow exch def
		/yopen exch def
		/x exch xmarkgap add def
		/dx xmarkgap 0.75 mul powidth 2 div sub def
		/dy yclose yopen sub def
		2 setlinecap
		newpath
		    x ylow moveto
		    x yopen lineto
		    x yhigh moveto
		    x yclose lineto
		stroke
		newpath
		    x yopen moveto
		    0 dx sub 0 rlineto
		    0 dy rlineto
		    dx 0 rlineto
		    dx 0 rlineto
		    0 0 dy sub rlineto
		    0 dx sub 0 rlineto
		yclose yopen lt { fill }{ stroke } ifelse
	    end end
	} bind def
	% x yopen ylow yhigh yclose => _

	/candlefill {
	    gpaperdict begin
	    gstockdict begin
		/yclose exch def
		/yhigh exch def
		/ylow exch def
		/yopen exch def
		/x exch xmarkgap add def
		/dx xmarkgap 0.75 mul powidth sub def
		yclose yopen lt {
		    /dy yclose yopen sub powidth add def
		    dy 0 ge { /dy 0 def } if
		    2 setlinecap
		    newpath
		    x yopen powidth 2 div sub moveto
		    0 dx sub 0 rlineto
		    0 dy rlineto
		    dx 0 rlineto
		    dx 0 rlineto
		    0 0 dy sub rlineto
		    0 dx sub 0 rlineto
		    fill
		} if
	    end end
	} bind def
	% x yopen ylow yhigh yclose => _

	/make_close {
	    gsave point_inner closemark grestore
	}bind def
	% x yopen ylow yhigh yclose => _

	/make_close2 {
	    5 copy
	    gsave point_outer closemark grestore
	    gsave point_inner closemark grestore
	}bind def
	% x yopen ylow yhigh yclose => _
	
	/closemark {
	    gpaperdict begin
	    gstockdict begin
		/yclose exch def
		/yhigh exch def
		/ylow exch def
		/yopen exch def
		/x exch xmarkgap add def
		/dx xmarkgap powidth 2 div sub def
		2 setlinecap
		newpath
		x yclose moveto
		x dx add yclose lineto
		stroke
	    end end
	} bind def
	% x yopen ylow yhigh yclose => _

	end % stockdict
END_FUNCTIONS

}

=head2 gstockdict

A few functions are defined in the B<gstockdict> dictionary.  These provide the code for the shapes drawn as price
marks.  These dictionary entries are defined:

    make_stock	 Draw single price mark
    make_stock2  Draw double price mark
    make_candle	 Draw Japanese candle mark
    make_candle2 Draw Japanese candle mark
    make_close	 Draw single closing price mark
    make_close2  Draw double closing price mark
    yclose	 parameter
    ylow	 parameter
    yhigh	 parameter
    yopen	 parameter
    x		 parameter
    dx		 working value
    dy		 working value

A postscript function suitable for passing to the C<shape> option to B<new> must have 'make_' preprended to the
name.  It should take 5 parameters similar to the code for C<shape => 'stock'> which is called as follows.

    x yopen ylow yhigh yclose make_stock
    
=cut

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
L<Finance::Share::Function> and L<Finance::Share::Line>.
Also, L<Finance::Share::test> covers writing your own tests.

=cut

1;

