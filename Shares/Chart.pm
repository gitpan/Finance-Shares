package Finance::Shares::Chart;
our $VERSION = 0.17;
use strict;
use warnings;
use Exporter;
use PostScript::File	     1.00 qw(check_file str);
use PostScript::Graph::Bar   0.03;
use PostScript::Graph::Key   1.00;
use PostScript::Graph::Paper 1.00;
use PostScript::Graph::Style 1.00;
use PostScript::Graph::XY    0.04;
use Finance::Shares::Sample  0.12 qw(ymd_from_string day_of_week);

#use TestFuncs qw(show show_deep show_lines);

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(deep_copy);

# These are the option keys for each graph
our @graphs = qw(prices volumes cycles tests);
our %titles = ( prices => 'Prices', volumes => 'Volumes', cycles => 'Cycles', tests => 'Tests');
our $default_percent = 20;

our $highest_int = 10 ** 20;	# how do you set these properly?
our $lowest_int = -$highest_int;

=head1 NAME

Finance::Shares::Chart - Draw stock quotes on a PostScript graph

=head1 SYNOPSIS

    use Finance::Shares::Chart;
    use Finance::Shares::Chart 'deep_copy';

    # ensure quotes data exists
    my $fss = new Finance::Shares::Sample(...);
    
    # add data lines with e.g.
    $fss->add_line('prices', $id, $data, $key, $style);
    
    # optional support objects
    my $psf = new PostScript::File(...);
    my $seq = new PostScript::Graph::Sequence;
    $seq->setup(...);
    $seq->auto(...);
    
    # create the Chart object
    my $fsc = new Finance::Shares::Chart(
	file	=> $psf,
	sample	=> $fss,
		
	dots_per_inch => 72,
	background    => [1, 1, 0.9],
	bgnd_outline  => 1,
	reverse       => 1,
	heading	      => 'Results chart',

	heading_font => {
	    font => 'Times-Bold',
	    size => 12,
	    color => [0, 0, 0.7],
	},
	
	normal_font => {
	    # as heading_font
	},
	
	key	    => {
	    # see PostScript::Graph::Key
	},
	
	x_axis	    => {
	    show_lines  => 1,
	    show_weekday=> 1,
	    show_day    => 1,
	    show_month  => 1,
	    show_year   => 1,
	    changes_only=> 0,
	    # see PostScript::Graph::Paper
	},

	prices	=> {
	    sequence	=> $seq,
	    show_dates	=> 1,
	    percent	=> 25,
	    layout	=> {
		# see PostScript::Graph::Paper
	    },
	    y_axis	=> {
		smallest    => 4,
		# see PostScript::Graph::Paper
	    },
	    points => {
		# style settings
	    },
	},
	
	volumes	=> {
	    # as prices, but with 'bars'
	    # instead of 'points'
	},
	
	cycles	=> {
	    # as prices, but without 'points'
	},
	
	tests	=> {
	    # as prices, but without 'points'
	},
    );

    # draw the chart and output it
    $fsc->build_chart();
    $fsc->output($filename);

=head1 DESCRIPTION

The chart produced by this module is about A4 size by default and has up to four graphs stacked vertically,
with key panels to the right of each one.

=over 10

=item prices

This panel must always be present.  It shows the share prices, usually showing opening and closing
prices on a high-low range.  Lines drawn on this are usually functions acting on the price data.

=item volumes

If volume data exists, it is placed on this chart.  Lines drawn here are usually functions acting on the volume
data.

=item cycles

This axis has a negative as well as a positive range, designed for graphing functions describing how the prices
change.

=item tests

Tests applied to functions from the other graphs would typically place their results here.  By default, the axis
ranges from 0 to 100 to indicate a confidence percentage.

=back

Specifications are given to the constructor, the most important being the Finance::Shares::Sample holding the data
and function and test lines.  Lines can be added to the sample until B<build_chart> is invoked, typically by
calling the B<output> method.

As can be seen from the L</SYNOPSIS> there are a number of top-level parameters which apply to all visible graphs,
followed by a sub-group controlling each graph independently.  Of particular interest are the graph parameters
B<percent> and B<show_dates> which control how the vertical space is allocated.  Horizontal space is allocated
automatically, with the key panels taking up as much space as needed to describe the superimposed lines.

Each graph also has its own B<sequence>.  This tries to make sure that the lines on that graph all have different
characteristics in terms of colour, point shape, dash pattern and so on.

If no PostScript::File is given to the constructor, one is generated.  However, passing an existing
PostScript::File object means that several charts can be placed on the one file.  See L</build_chart>.

=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my $o = {};
    if (@_ == 1) { $o = $_[0]; } else { %$o = @_; }
    bless( $o, $class );
    
    ## Ensure PostScript::File exists
    my $pf = $o->{file};
    if (ref $pf eq 'PostScript::File') {
	$o->{pf} = $pf;
    } else {
	my $of = $o->{pf};
	$of->{paper}     = 'A4' unless (defined $of->{paper});
	$of->{landscape} = 1    unless (defined $of->{landscape});
	$of->{left}      = 36   unless (defined $of->{left});
	$of->{right}     = 36   unless (defined $of->{right});
	$of->{top}       = 36   unless (defined $of->{top});
	$of->{bottom}    = 36   unless (defined $of->{bottom});
	$of->{errors}    = 1    unless (defined $of->{errors});
	$o->{pf} = new PostScript::File( $pf );
    }
    ## Ensure Sample known
    warn 'No Finance::Shares::Sample' unless $o->{sample} and ref($o->{sample}) eq 'Finance::Shares::Sample';
    $o->{sample}->chart($o);
    
    ## Defaults for common X axes
    $o->{x_axis}    = {} unless defined $o->{x_axis};
    my $x = $o->{x_axis};
    $x->{show_lines} = 1 unless defined $x->{show_lines};
    $x->{mark_max}   = 4 unless defined $x->{mark_max};

    ## Defaults for prepare_labels
    $o->{heading_font}{size} = 12  unless defined $o->{heading_font}{size};
    $o->{normal_font}{size}  = 10  unless defined $o->{normal_font}{size};
    $o->{glyph_ratio}        = 0.5 unless defined $o->{glyph_ratio};
    $o->prepare_labels();
    
    ## Common settings for Chart option hash
    my $s = $o->{sample};
    $o->{totalpc}   = 0;
    $o->{totalx}    = 0;
    my $dates_shown = 0;
    foreach my $i (0 .. $#graphs) {
	my $g = $graphs[$i];
	$o->{$g} = {} unless defined $o->{$g};
	my $h = $o->{$g};
	
	## top level
	$h->{file} = $o->{pf};
	unless (defined $h->{sequence} and ref($h->{sequence}) eq 'PostScript::Graph::Sequence') {
	    $h->{sequence} = new PostScript::Graph::Sequence;
	}
	#warn "$g default Sequence = ", $h->{sequence}->id(), "\n";
	unless ($dates_shown) {
	    $h->{show_dates} = 1 unless defined $h->{show_dates};
	    $dates_shown = $h->{show_dates};
	}

	## layout
	$h->{layout} = {} unless defined $h->{layout};
	my $l = $h->{layout};
	$l->{dots_per_inch} = $o->{dots_per_inch};
	$l->{background} = $o->{background};
	$l->{heading_font} = $o->{heading_font}{font};
	$l->{heading_font_size} = $o->{heading_font}{size};
	$l->{heading_font_color} = $o->{heading_font}{color};
	$l->{font} = $o->{normal_font}{font};
	$l->{font_size} = $o->{normal_font}{size};
	$l->{font_color} = $o->{normal_font}{color};
	$l->{top_margin} = 3 unless defined $l->{top_margin};;
	$l->{no_drawing} = 1;	# delay drawing until labels have been checked
	if ($g eq 'prices') {
	    my $s = $o->{sample};
	    $l->{heading} = $o->{heading} ? $o->{heading} : ($s->symbol . ' ' . $s->dates_by . ' from ' . $s->start_date . ' to ' . $s->end_date);
	    $l->{heading_height} = $l->{heading_font_size} unless defined $l->{heading_height};
	} else {
	    $l->{heading_height} = 5 unless defined $l->{heading_height};
	}
	
	## x_axis
	$h->{x_axis} = { %{$o->{x_axis}} } unless defined $h->{x_axis};
	my $x = $h->{x_axis};
	$x->{draw_fn} = 'xdrawstock';
	$x->{offset} = 1;
	$x->{sub_divisions} = 2;
	$x->{center} = 0;
	if ($h->{show_dates}) {
	    $x->{labels} = $o->{labels};
	    $x->{glyph_ratio} = $o->{glyph_ratio};
	    $o->{totalx}++;
	} else {
	    $x->{labels} = $o->{dlabels};
	    $x->{mark_max} = 0;
	    #$x->{height} = 6;
	}
	
	## y_axis
	$h->{y_axis} = {} unless defined $h->{y_axis};
	my $y = $h->{y_axis};
	$y->{low} = $s->{$g}{min};
	$y->{high} = $s->{$g}{max};
	$y->{title} = $titles{$g};
	$y->{smallest} = $o->{smallest} unless defined $y->{smallest};
	
	## key
	$h->{key} = deep_copy($o->{key});
    }
    
    ## Individual settings
    {
	$o->{prices}{points} = {} unless defined $o->{prices}{points};
	my $pp = $o->{prices}{points};
	$pp->{shape} = 'stock2' unless defined $pp->{shape};
	$pp->{shape} = 'stock2' unless $pp->{shape} eq 'stock2' or $pp->{shape} eq 'stock'
	    or $pp->{shape} eq 'candle' or $pp->{shape} eq 'candle2'
	    or $pp->{shape} eq 'close2' or $pp->{shape} eq 'close';
	
	$o->{volumes}{bars} = {} unless defined $o->{volumes}{bars};
	
	$o->{prices}{y_axis}{si_shift} = 0 unless defined $o->{prices}{y_axis}{si_shift};
    }

    return $o;
}

=head2 new( options )

C<options> can be a hash ref or a list of hash keys and values.  The top level keys are as follows.

=over 4

=item background

The background colour for all the graphs.  This can be a shade of grey (0.0 for black, 1.0 for brightest) or
an array ref holding similar decimals for red, green and blue, e.g. [ 0.6, 0.4, 0 ] for a red-orange.  (Default:
1.0)

=item bgnd_outline

By default the price and volume marks are drawn with a contrasting outline.  Setting this to 1 makes this outline
the same colour as the background.  (Default: 0)

=item changes_only

The dates can be shown with every part (day, month etc) shown on every label, or with these parts only shown when
they change.  (Default: 1)

=item cycles

A hash ref controlling the appearance of the cycles graph.  See L</'Individual graphs'> for details.

=item dots_per_inch

One of the advantages of PostScript output is that it can make the best use of each medium.  Setting this to 72
produces output suitable for most computer monitors.  Use a higher figure for hard copy, depending on you
printer's capabilities.  (Default: 300)

=item file

This can be either a PostScript::File object or a hash ref holding parameters suitable for creating one.  The
default is to set up a landscape A4 page with half inch margins.

=item glyph_ratio

Generating PostScript is a one-way process.  It is not possible to find out how much space will be taken up by
a string using a proportional spaced font, so guesses are made.  This allows that guess to be fine tuned.
(Default: 0.5)

=item heading_font

A hash ref holding font settings for the main heading.  See B<normal_font> for details.

=item reverse

If true, the order in which lines are drawn is reversed.

=item key

A hash ref controlling the appearance of the key panels.  The following keys are recognized.  See
L<PostScript::Graph::Key> for details.

    background	    outline_color	outline_width
    title	    title_font		text_font
    spacing	    horz_spacing	vert_spacing
    text_width	    icon_height		icon_width
    glyph_ratio

=item normal_font

A hash ref holding font settings for the text used for axis labels etc.  It may contain these keys:

=over 4

=item font

The font family name which should be one of the following.  (Default: 'Helvetica')

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

Point size to use.  (Default: 10)

=item color

The normal colour format: either a grey value or an array ref holding [<red>,<green>,<blue>].  (Default: 1.0)

=back

=item page

An optional string used as the PostScript page 'number'.  Although this may be anything many programs expect this
to be short like a page number, with no spaces.

=item prices

A hash ref controlling the appearance of the prices graph.  See L</'Individual graphs'> for details.

=item sample

The L<Finance::Shares::Sample> object holding the data to be displayed.  Required - no default.

=item tests

A hash ref controlling the appearance of the prices graph.  See L</'Individual graphs'> for details.

=item smallest

The underlying PostScript::Graph::Paper module will sometimes generate more subdivisions and axis lines than
needed, especially at high resolutions.  C<smallest> provides some control over this for the Y axes.  It specifies
the size of the smallest gap between lines; giving a larger number means fewer lines.  The default produces 3 dots
at the resolution given to B<dots_per_inch>.

Note that the only way to control the line density on the X axis is to plot fewer dates.  One way of doing this is
to set the Finance::Shares::Sample contructor option C<dates_by> to 'weeks' or 'months'.

=item volumes

A hash ref controlling the appearance of the volumes graph.  See L</'Individual graphs'> for details.

=item x_axis

A hash ref controlling the appearance of the dates axis and the vertical grid lines.  These keys are defined in
this module:

=over 4

=item show_lines

True means that vertical lines are to be shown on all the graphs.  This can get a little crowded if a lot of dates
are shown.  (Default: 1)

=item show_weekday

True means the day of the week is to be shown on the date axis.  (Default: 0)

=item show_day

True means the day of the month is to be shown on the date axis.  The default depends on the timescale of the sample.

=item show_month

True means the month abbreviation is to be shown on the date axis.  The default depends on the timescale of the
sample.

=item show_year

True means the year is to be shown on the date axis.  The default depends on the timescale of the sample.

=item changes_only

The date labels can either show all parts (day, month etc.) on every date or only show them as they change.
(Default: 1)

=back

These keys are also recognized within x_axis.  See L<PostScript::Graph::Paper> for details.

    title	    color
    heavy_color	    mid_color
    heavy_width	    mid_width
    mark_min	    mark_max

'heavy' vertical lines are those marked with a date lablel.  Date positions whose labels have been omitted are
marked with 'mid' lines.  Although there is no way to stop these from being drawn, the chart can be made visually
simpler by setting C<mid_width> to 0 and/or C<mid_color> to the background color.
    
=back

=head3 Individual graphs

B<prices>, B<volumes>, B<cycles> and B<tests> all use extensive hash refs.  More or less, these are passed on to
L<PostScript::Graph::Paper> and friends.  To make them more manageable, they are broken down into sub-hashes.
Here are the top level keys within each graph.

=over 4

=item bars

A hash ref controlling how the volume data is to be displayed.  Only relevant for the volume graph.
These are the recognized keys; see L<PostScript::Graph::Style> for details.

    color	inner_color	outer_color
    width	inner_width	outer_width

=item layout

A hash ref controlling some general aspects of the graph.  The following keys are recognized.  See
L<PostScript::Graph::Paper> for details.

    spacing	top_margin  right_margin

=item percent

This is the proportion of space allocated to the graph.  Specifying 0 hides it.  It is not a strict percentage in
that they don't all have to add up to 100, but it does give an idea of the sort of numbers to put here.  There may
be problems if the value is less than 10, or so small the graph cannot physically be drawn in the space.  

Some graphs will become visible automatically (provided their percent is not 0) if data or lines should be shown
there.  They take a default value of 20.

=item points

A hash ref controlling how the price data is to be displayed.  Only relevant for the price graph.
These are the recognized keys; see L<PostScript::Graph::Style> for details.

    size	shape*	    color	width
    inner_color	outer_color inner_width	outer_width

*The allowed values for shape are B<NOT> as listed under L<PostScript::Graph::Style/shape>.  Instead they are:

=over 8

=item stock2

Draw the normal open, high-low, close mark in the normal colour (C<inner_color>) with an outer edge drawn in
C<outer_color>.

=item stock

Draw the normal open, high-low, close mark in the normal colour (inner_color) with no outer edge.  This can make
the drawing a little faster as no outline is drawn.

=item close2

Draw the close mark only in the normal colour (C<inner_color>) with an outer edge drawn in
C<outer_color>.

=item close

Draw the close mark only in the normal colour (C<inner_color>) with no outer edge.

=item candle2

Draw a Japanese candlestick in C<outer_color>, filled with C<inner_color>.  Don't use this with C<bgnd_outline>
set to 1 as most of the marks will disappear!

=item candle

Draw a Japanese candlestick in one pass, the filling and outline both in normal colour (C<inner_color>).

=back

=item sequence

Lines added to a graph are shown by default with slightly differing styles controlled by
a PostScript::Graph::Sequence object.  Each graph has a default sequence which can be accessed by the
B<sequence()> method.  Alternatively, you can set up your own sequence and declare it here.  See
L<PostScript::Graph::Style> for details.

=item show_dates

True if the dates axis is to be shown under this chart.  By default the dates are placed under the first graph
that hasn't specified show_dates => 0.
   
=item y_axis

These keys are recognized within y_axis.  See L<PostScript::Graph::Paper> for details.

    color	heavy_color mid_color	light_color
    smallest	heavy_width mid_width	light_width
    title	mark_min    mark_max	label_gap
    si_shift

=back

=cut

=head1 MAIN METHODS

=cut

sub sequence {
    my ($o, $graph) = @_;
    return $o->{$graph}{sequence};
}

=head2 sequence( graph )

This provides access to the PostScript::Graph::Sequence object which by default controls the styles of lines
placed on each of the graphs.  C<graph> is one of 'prices', 'volumes', 'cycles', 'tests'.

Example

Here, a number of lines (moving averages) are drawn on a chart.  Each line will be given a different colour even
though they are all have the same style options.

    my $fss = Finance::Shares::Sample(
	... );
    my $fsc = Finance::Shares::Chart(
	sample	 => $fss, ... );

    my $pseq = $fsc->sequence( 'prices' );
    $pseq->auto( qw(color dashes shape) );
    
    my $style = {
	sequence => $pseq,
	width	 => 2,
    };
    
    $fss->simple_average(
	period	 => 5,
	style	 => $style,
    );

    $fss->simple_average(
	period	 => 15,
	style	 => $style,
    );

    $fss->simple_average(
	period	 => 30,
	style	 => $style,
    );

See L<PostScript::Graph::Style> for details concerning sequences and styles.
    
=cut
    
sub output {
    my ($o, @args) = @_;
    $o->build_chart() unless $o->{built};

    return $o->{pf}->output(@args);
}

=head2 output( [filename [, directory]] )

The graphs are constructed and written out to a PostScript file.  A suitable suffix (.ps, .epsi or .epsf) will be
appended to the file name.

If no filename is given, the PostScript text is returned.  This makes handling CGI requests easier.

=cut

=head1 SUPPORT METHODS

=cut

sub build_chart {
    my ($o, $pf) = @_;
    my $s = $o->{sample};
    $o->{pf} = $pf if defined $pf;
    $o->{pf}->set_page_label( $o->{page} ) if defined $o->{page};
    my $t = $o->{test};	    # may be undef or 0

    ## open dictionaries
    PostScript::Graph::Paper->ps_functions( $o->{pf} );
    PostScript::Graph::Key->ps_functions( $o->{pf} );
    PostScript::Graph::XY->ps_functions( $o->{pf} );
    Finance::Shares::Chart->ps_functions( $o->{pf} );
    PostScript::Graph::Style->ps_functions( $o->{pf} );
    
    $o->{pf}->add_to_page( <<END_INIT );
	gpaperdict begin
	gstyledict begin
	xychartdict begin
	gstockdict begin
END_INIT

    ## Calculate height
    my @pagebox = $o->{pf}->get_page_bounding_box();
    my $label_space = $o->{totalx} * $o->{lblspc};
    my $heading_space = $o->{heading_font}{size} - 5;
    my $top = $pagebox[3]-1;
    my $bottom = $pagebox[1]+1;
    my $full_height = $top - $bottom - $heading_space - $label_space;

    ## Check for visibility
    $o->{totalpc} = 0;
    foreach my $g (@graphs) {
	my $h = $o->{$g};
	if ($h->{reverse}) {
	    my $lines = $s->line_order($g);
	    @$lines = sort { -($s->{lines}{$g}{$a}{order} <=> $s->{lines}{$g}{$b}{order}) } @$lines if $lines;
	}
	my $hidden = (defined $h->{percent} && $h->{percent} == 0);
	$h->{percent} = 0 unless defined $h->{percent};
	$h->{visible} = 0;
	if ($g eq 'prices') {
	    $h->{percent} = $default_percent unless $h->{percent} > 0;
	    $o->{totalpc} += $h->{percent};
	    $h->{visible} = 1;
	} elsif (not $hidden) {
	    if ($g eq 'volumes' and $s->{volume} and %{$s->{volume}}) {
		$h->{percent} = $default_percent unless $h->{percent} > 0;
	    }
	    foreach my $l (values %{$s->{lines}{$g}}) {
		if ($o->visible($g, $l)) {
		    $h->{percent} = $default_percent unless $h->{percent} > 0;
		    last;
		}
	    }
	    if ($h->{percent}) {
		$h->{visible} = 1;
		$o->{totalpc} += $h->{percent};
	    }
	}
	#warn "Chart: $g = $h->{percent}% ($h->{visible}); total=$o->{totalpc}\n";
    }
 
    ## create Key panels 
    my $key_width = 0;
    foreach my $g (@graphs) {
	my $h = $o->{$g};
	next unless $h->{percent};
	$h->{height} = $full_height * $h->{percent}/$o->{totalpc};
	$h->{height} += $heading_space if $g eq 'prices';
	$h->{height} += $o->{lblspc} if $h->{show_dates};

	if ($o->visible_lines($g)) {
	    my @key_labels;
	    my $maxlen  = 0;
	    my $maxsize = $o->{normal_font}{size};
	    my $lwidth  = 3;
	    my $y = $h->{y_axis};
	    $y->{high} = $lowest_int unless defined $y->{high};
	    $y->{low} = $highest_int unless defined $y->{low};
	    ##   create style
	    my ($id, $base);
	    while( ($id, $base) = each %{$s->{lines}{$g}} ) {
		next unless $o->visible($g, $base);
		my $style = $base->{style};
		unless (defined($style) and ref($style) eq 'PostScript::Graph::Style') {
		    $style = {} unless defined $style;
		    my $none = (defined($style->{line}) or defined($style->{point}) or defined($style->{bar}));
		    $style->{line} = {} unless $none;
		    $style->{point} = {} unless $none;
		    $style->{label} = $base->{key};
		    $style->{sequence} = $h->{sequence} unless defined $style->{sequence};
		    $style = $base->{style} = new PostScript::Graph::Style( $style ); 
		}
		#warn "build_chart $g id=$id, style=", $style->id(), "\n";
		unless (defined $h->{line_styles}{$style}) {
		    $h->{line_styles}{$style} = $base;	    # multiple styles must appear only once
		    push @key_labels, $base->{key};
		}
		my $lw   = $style->use_line() ? $style->line_outer_width() : 0;
		$lwidth  = $lw/2 if ($lw/2 > $lwidth);
		my $size = $style->use_point() ? $style->point_size() + $lwidth : $lwidth;
		$maxsize = $size if ($size > $maxsize);
		my $len	 = length($base->{key});
		$maxlen	 = $len if ($len > $maxlen);
		# ensure scales fit around each line
		$y->{low} = $base->{min} if $base->{min} < $y->{low};
		$y->{high} = $base->{max} if $base->{max} > $y->{high};
	    }
	    
	    $h->{key} = {} unless defined $h->{key};
	    my $k = $h->{key};
	    $k->{max_height}  = $h->{height} - $o->{normal_font}{size} * 1.5;
	    $k->{item_labels} = \@key_labels;
	    $k->{title}	      = $titles{$g} . ' key' unless defined $k->{title};
	    $k->{icon_width}  = $maxsize * 3 unless defined $k->{icon_width};

	    my $max_width     = 0.2 * ($pagebox[2] - $pagebox[0]);
	    $max_width       -= ($k->{icon_width} - 3 * $lwidth);
	    my $tsize         = defined($k->{text_size}) ? $k->{text_size} : 10;
	    unless (defined $k->{text_width}) {
		$k->{text_width}  = $maxlen * $tsize * $o->{glyph_ratio};
		$k->{text_width}  = $max_width if $k->{text_width} > $max_width;
	    }
	    
	    $k->{icon_height} = $maxsize * 1.2 unless defined $k->{icon_height};
	    $k->{spacing}     = $lwidth unless defined $k->{spacing};
	    $k->{file}	      = $o->{pf};
	    $h->{pgk} = new PostScript::Graph::Key( $k );
	    my $kw            = $h->{pgk}->width();
	    $key_width        = $kw if ($kw > $key_width);
	}
    }
    
    ## Graph grids
    foreach my $g (@graphs) {
	my $h = $o->{$g};
	next unless $h->{percent};
	my $l = $h->{layout};
	$l->{top_edge} = $top;
	$top = $l->{bottom_edge} = $top - $h->{height};
	$l->{key_width} = $key_width;
	$h->{pgp} = new PostScript::Graph::Paper( $h );
    }
 
    ## adjust date labels to fit
    # Avoids date labels overwriting each other when there are too many
    {
	my $pgp = $o->{prices}{pgp};
	my $space_reqd  = @{$o->{labels}} * $pgp->x_axis_font_size();
	my $graph_width = $pgp->x_axis_width();
	my $skip = int($space_reqd/$graph_width);
	if ($space_reqd > $graph_width) {
	    $o->prepare_labels($skip);
	    foreach my $g (@graphs) {
		my $h = $o->{$g};
		next unless $h->{percent};
		my $pgp = $h->{pgp};
		if ($pgp) {
		    if ($h->{show_dates}) {
			$pgp->x_axis_labels( $o->{labels} );
		    } else {
			$pgp->x_axis_labels( $o->{dlabels} );
		    }
		    $pgp->draw_scales();
		}
	    }
	} else {
	    foreach my $g (@graphs) {
		my $pgp = $o->{$g}{pgp};
		$pgp->draw_scales() if $pgp;
	    }
	}
    }
    
    ## Price marks
    {
	my $h = $o->{prices};
	my $pgp = $h->{pgp};
	my $sh = {
	    auto  => 'none',
	    same  => $o->{bgnd_outline},
	    point => $h->{points}, 
	};
	my $pstyle = new PostScript::Graph::Style( $sh );
	$pstyle->background( $pgp->layout_background() );
	$pstyle->write( $o->{pf} );
	my $open = $s->{open};
	my $high = $s->{high};
	my $low = $s->{low};
	my $close = $s->{close};
	my $lx = $s->{lx};
	my $count = 0;
	my $ymin = $highest_int;
	my $ymax = $lowest_int;
	foreach my $date (@{$s->{dates}}) {
	    my $psx = $pgp->px( $lx->{$date} );
	    if (defined $open->{$date}) {
		my $oy = $pgp->py( $open->{$date} );
		my $hy = $pgp->py( $high->{$date} );
		my $ly = $pgp->py( $low->{$date} );
		my $cy = $pgp->py( $close->{$date} );
		$pgp->add_to_page("$psx $oy $ly $hy $cy ppshape\n");
		$count++;
		$ymin = $ly if $ly < $ymin;
		$ymax = $hy if $hy > $ymax;
	    }
	}
	if ($t) {
	    $t->{prices_count} = $count;
	    $t->{prices_ymin} = $ymin;
	    $t->{prices_ymax} = $ymax;
	}
    }
   
    ## Volume marks
    if ($o->{sample}{volume} and $o->{volumes}{percent}) {
	my $h = $o->{volumes};
	my $sh = {
	    auto => 'none',
	    same => $o->{bgnd_outline},
	    bar  => $h->{bars},
	};
	my $pgp = $h->{pgp};
	my $vstyle = new PostScript::Graph::Style( $sh );
	$vstyle->background( $pgp->layout_background() );
	$vstyle->write( $o->{pf} );
	my $volume = $s->{volume};
	my $lx = $s->{lx};
	my $count = 0;
	my $ymin = $highest_int;
	my $ymax = $lowest_int;
	foreach my $date (@{$s->{dates}}) {
	    my $x = $lx->{$date};
	    my $y = $volume->{$date};
	    if (defined $y) {
		my @bb     = $pgp->vertical_bar_area($x * 2, $y);
		my $lwidth = $vstyle->bar_outer_width()/2;
		$bb[0] += $lwidth;
		$bb[1] += $lwidth;
		$bb[2] -= $lwidth;
		$bb[3] -= $lwidth;
		$bb[3] = $bb[1] if ($bb[3] < $bb[1]);
		$o->{pf}->add_to_page( <<END_BAR );
		    $bb[0] $bb[1] $bb[2] $bb[3] bocolor bowidth drawbox
		    $bb[0] $bb[1] $bb[2] $bb[3] bicolor bicolor biwidth fillbox
END_BAR
		$count++;
		$ymin = $bb[1] if $bb[1] < $ymin;
		$ymax = $bb[3] if $bb[3] > $ymax;
	    }
	}
	$h->{percent} = 0 unless $count;
	if ($t) {
	    $t->{volumes_count} = $count;
	    $t->{volumes_ymin} = $ymin;
	    $t->{volumes_ymax} = $ymax;
	}
    }

    ## Add lines
    foreach my $g (@graphs) {
	my $h = $o->{$g};
	$h->{pgk}->build_key($h->{pgp}) if defined $h->{pgk};
	$o->build_lines($g);
    }

    ## close dictionaries
    $o->{pf}->add_to_page( "end end end end\n" );
    $o->{built} = 1;
}



=head2 build_chart( [file] )

If given, C<file> should be a PostScript::File object or a hash ref suitable for creating one.

This writes the appropriate PostScript to either the file given or one created internally.  This is normally called by
B<output()> and should only need calling directly if several charts are to be placed on the same file.

Example

    # Create the file
    my $pf = new PostScript::File(...);

    # Create the necessary samples
    my $s1 = new Finance::Shares::Sample(...);
    my $s2 = new Finance::Shares::Sample(...);
    my $s3 = new Finance::Shares::Sample(...);
    
    # add lines as required
    $s1->add_line(...);
    $s2->add_line(...);
    ...
    
    # Create a chart object for each sample
    my $ch1 = new Finance::Shares::Chart(
	file   => $pf,
	sample => $s1,
	... );
    my $ch2 = new Finance::Shares::Chart(
	file   => $pf,
	sample => $s2,
	... );
    my $ch3 = new Finance::Shares::Chart(
	file   => $pf,
	sample => $s3,
	... );

    # add more lines if required
    $s3->add_line(...);
    
    # Build the charts on seperate pages
    $ch1->build_chart();
    $pf->newpage();
    
    $ch2->build_chart();
    $pf->newpage();
    
    $ch3->build_chart();
    $pf->newpage();

    # Output the file
    $pf->output($filename);



=cut

sub build_lines {
    my ($o, $g) = @_;
    my $s = $o->{sample};
    my $h = $o->{$g};
    return unless $h->{visible};
    my $pgp = $h->{pgp};	# PostScript::Graph::Paper
    my $pgk = $h->{pgk};	# PostScript::Graph::Key
    my $t = $o->{test};		# may be undef, 0 or {...}
    
    my ($cmd, $keylines, $keyouter, $keyinner);
    my $lines = $s->line_order($g);
    foreach my $id (@$lines) {
	my $base = $s->{lines}{$g}{$id};
	next unless $o->visible($g, $base);
	my $pgs = $base->{style};
	#warn "build_line ", $s->id(), " $g, $id, ", $pgs->id(), ")\n";
	die "Line style is not a Style\n" unless ref($pgs) eq "PostScript::Graph::Style";
	$pgs->background( $pgp->layout_background() );
	$pgs->write( $o->{pf} );

	if ($pgs->use_bar()) {
	    ## construct bar data
	    foreach my $date (sort keys %{$base->{data}}) {
		my $y = $base->{data}{$date};
		if (defined $y) {
		    my $x = $s->{lx}{$date};
		    if (defined $x) {
			my @bb = $pgp->vertical_bar_area($x * 2, $y);
			my $lwidth = $pgs->bar_outer_width()/2;
			$bb[0] += $lwidth;
			$bb[1] += $lwidth;
			$bb[2] -= $lwidth;
			$bb[3] -= $lwidth;
			$o->{pf}->add_to_page( <<END_BAR );
			    $bb[0] $bb[1] $bb[2] $bb[3] bocolor bowidth drawbox
			    $bb[0] $bb[1] $bb[2] $bb[3] bicolor bicolor biwidth fillbox
END_BAR
		    } else {
			warn "UNKNOWN DATE: $date (y=$y) in line $id";
		    }
		}
	    }
	} else {
	    ## construct point data
	    my $points = "";
	    my $npoints = -1;
	    foreach my $date (sort keys %{$base->{data}}) {
		my $y = $base->{data}{$date};
		if (defined $y) {
		    my $x = $s->{lx}{$date};
		    if (defined $x) {
			my $px = $pgp->px($x + 0.5);
			my $py = $pgp->py($y);
			$points = "$px $py " . $points;
			$npoints += 2;
		    } else {
			warn "UNKNOWN DATE: $date (y=$y) in line $id";
		    }
		}
	    }
	    $t->{lines}{$id} = ($npoints+1)/2 if ($t);
		
	    ## prepare code for points and lines
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
	    $o->{pf}->add_to_page( "[ $points ] $npoints $cmd\n" ) if ($cmd);
	}
	$t->{nlines}++ if $t;
    }

    ## make key entries
    my @styles;
    {	#TODO move this up so lines are drawn in the same order
	my (@lines, @signals);
	foreach my $entry (values %{$h->{line_styles}}) {
	    my $id = $entry->{id};
	    if ($id =~ /^signal/) {
		push @signals, $entry;
	    } else {
		push @lines, $entry;
	    }
	}
	@signals = sort { $a->{order} <=> $b->{order} } @signals;
	@lines = sort { $a->{order} <=> $b->{order} } @lines;
	@styles = (@lines, @signals);
    }
    foreach my $sdata (@styles) {
	my $pgs = $sdata->{style};
	die "Not a Style\n" unless ref($pgs) eq "PostScript::Graph::Style";
	$pgs->background( $pgp->layout_background() );
	$pgs->write( $o->{pf} );
	
	if ($pgs->use_bar()) {
	    ## prepare code for key bar entries
	    my $colour = str($pgs->bar_inner_color());
	    $pgk->add_key_item( $sdata->{key}, <<END_KEY ) if defined $pgk;
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
	} else {
	    ## prepare code for key points and lines
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

	    $pgk->add_key_item( $sdata->{key}, <<END_KEY ) if (defined $pgk);
		2 dict begin
		    /kpx kix0 kix1 add 2 div def
		    /kpy kiy0 kiy1 add 2 div def
		    $keyouter
		    $keylines
		    $keyinner
		end
END_KEY
	}
    }
}

sub prepare_labels {
    my ($o, $skip) = @_;
    $skip = 0 unless defined $skip;
    my $s = $o->{sample};
 
    ## Identify date options
    my $dtype = $o->{sample}->dates_by();
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
    $dsdow   = defined($x->{show_weekday}) ? $x->{show_weekday}        : $dsdow;
    $dsday   = defined($x->{show_day})     ? $x->{show_day}            : $dsday;
    $dsmonth = defined($x->{show_month})   ? $x->{show_month}          : $dsmonth;
    $dsyear  = defined($x->{show_year})    ? $x->{show_year}           : $dsyear;
    $dsall   = defined($x->{changes_only}) ? ($x->{changes_only} == 0) : 0;
  
    ## Prepare for label creation
    warn 'No dates' unless @{$s->{dates}};
    my @days   = qw(- Mon Tue Wed Thu Fri Sat Sun);
    my @months = qw(- Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my (@labels, @dlabels);
    my $labellength = 0;
    
    my $ldow = 0;
    my ($lday, $lmonth, $lyear) = (0, 0, 0);
    my $skip_count = 0;
    
    my $open   = $s->{open};
    my $high   = $s->{high};
    my $low    = $s->{low};
    my $close  = $s->{close};
    my $volume = $s->{volume};
    
    ## Create labels and calc min/max values
    for my $date (@{$s->{dates}}) {
	my ($year, $month, $day) = ymd_from_string($date);
	my $dow = day_of_week($year, $month, $day);
	my $label = '';
	$label .= $days[$dow]     . ' ' if ($dsdow   and ($dsall or ($dow != $ldow)));
	$label .= $day            . ' ' if ($dsday   and ($dsall or ($day != $lday)));
	$label .= $months[$month] . ' ' if ($dsmonth and ($dsall or ($month != $lmonth)));
	$label .= $year		  . ' ' if ($dsyear  and ($dsall or ($year != $lyear)));
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
    $o->{lblspc} = $o->{x_axis}{mark_max} + (1 + $labellength * $o->{glyph_ratio}) * $o->{normal_font}{size};
    $o->{volumes}{percent} = 0 unless defined $s->{volumes}{max};
}
# If $skip > 0 the labels are being adjusted, so they must be in PostScript format, i.e. '(...)'

sub visible_lines {
    my ($o, $graph) = @_;
    my $count = 0;
    my $l = $o->{sample}{lines}{$graph};
    if ($l) {
	my ($id, $entry);
	while( ($id, $entry) = each %$l ) {
	    $count++ if $o->visible($graph, $entry);
	}
    }
    return $count;
}

sub visible {
    my ($o, $graph, $entry) = @_;
    return $o->{$graph}{visible} unless defined $entry;
    my $res = 0;
    $res = 1 if $entry->{shown} and %{$entry->{data}};
    return $res;
}

=head2 visible( graph [, entry ] )

Returns true if the graph or line is visible.  C<graph> must be one of the graph names.  If C<entry> is given it
should be a ref to the line's data structure, as stored in Sample.

=cut

sub sample {
    my $o = shift;
    return $o->{sample};
}

=head2 sample()

Return the Finance::Shares::Sample holding the data for this chart.

=cut

sub title {
    my $o = shift;
    return $o->{prices}{layout}{heading} || '';
}

=head2 title()

Return the heading printed at the top of the chart.

=cut

sub page {
    my ($o, $page) = @_;
    my $old = $o->{page};
    $o->{page} = $page if defined $page;
    return $old;
}

=head2 page( [id] )

Return the page identifier, if any.

If C<id> is given this replaces the returned value.

=cut

=head1 CLASS METHODS

The PostScript code is a class method so that it may be available to other classes that don't need a Stock object.

The useful functions in the 'gstockdict' dictionary draw a stock chart mark and a close mark in
either one or two colours.

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

=head1 EXPORTED FUNCTIONS

=cut

sub deep_copy {
    my ($orig) = @_;
    return undef unless defined $orig;
    my $ref = ref $orig;
    my $copy;

    if ($ref eq 'HASH') {
	$copy = {};
	foreach my $key (keys %$orig) {
	    my $value = $orig->{$key};
	    $copy->{$key} = deep_copy($value);
	}
    } elsif ($ref eq 'ARRAY') {
	$copy = [];
	foreach my $value (@$orig) {
	    push @$copy, deep_copy($value);
	}
    } else {
	$copy = $orig;
    }

    return $copy;
}

=head2 deep_copy( var )

C<var> is returned unless it is, or contains, a hash ref or  an array ref.  These are copied recursively and the
copy is returned.

=cut

=head1 BUGS

The complexity of this software has seriously outstripped the testing, so there will be unfortunate interactions.
Please do let me know when you suspect something isn't right.  A short script working from a CSV file
demonstrating the problem would be very helpful.

=head1 AUTHOR

Chris Willmot, chris@willmot.org.uk

=head1 SEE ALSO

L<Finance::Shares::Sample>,
L<PostScript::Graph::Style> and
L<Finance::Shares::Model>.

There is also an introduction, L<Finance::Shares::Overview> and a tutorial beginning with
L<Finance::Shares::Lesson1>.

=cut

1;

