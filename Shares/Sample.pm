package Finance::Shares::Sample;
our $VERSION = 0.11;
use strict;
use warnings;
use Exporter;
use Carp;
use Date::Calc qw(Today Date_to_Days Add_Delta_Days Delta_Days Day_of_Week);
use Text::CSV_XS;
use PostScript::Graph::Style 0.07;
use Finance::Shares::MySQL   1.03;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(%period %line 
		    line_id function
		    today_as_string string_from_ymd ymd_from_string
		    increment_days increment_date days_difference day_of_week);

# Used for constructing Key text
our %period = (
    days     => 'day', 
    weeks    => 'week', 
    months   => 'month'
);

# Maps line function names to methods
our %line = (
    open_x   => sub { return 'open'; },
    high_x   => sub { return 'high'; },
    low_x    => sub { return 'low'; },
    close_x  => sub { return 'close'; },
    volume_x => sub { return 'volume'; },
);
    
our $highest_int = 10 ** 20;	# how do you set these properly?
our $lowest_int = -$highest_int;
our $points_margin = 0.02;	# logical 0/1 is mark_range -/+ points_margin * mark_range

=head1 NAME

Finance::Shares::Sample - Price data on a single share

=head1 SYNOPSIS

    use Finance::Shares::Simple;

=head2 Simplest

Obtain a series of stock quotes from a CSV file.

    my $ss = new Finance::Shares::Sample(
		source  => 'gsk,csv',
		symbol  => 'GSK.L',
	    );


=head2 Typical

Get a series of stock quotes and graph them using specific settings.  Calculate some trend lines from the
Finance::Shares::Sample data and superimpose them on the graph.

    my $s = new Finance::Shares::Sample(
	    source => {
		user	 => 'guest',
		password => 'a94Hq',
		database => 'London',
	    },
	    
	    dates_by   => 'weeks',
	    symbol     => 'GSK.L',
	    start_date => '2001-09-01',
	    end_date   => '2002-08-31'
	);

    # construct data for lines, and then...
    $s->add_line( 'prices', 'one', $line1, 'Support' );
    $s->add_line( 'volumes', 'two', 'Average' );
    $s->add_line( 'cycles', 'three', $line3, 'RSI' );
	
    
=head1 DESCRIPTION

This module is principally a data structure holding stock quotes.  Price and volume data are held for a particular
share over a specified period.  This data can be read from a CSV file or from an array, but more usually it is
fetched from Finance::Shares::MySQL which in turn handles getting the data from the internet.

=head2 The Data

This object is used as a data structure common to a number of modules.  Therefore, unusually, most of the internal
data is made available directly.  Those documented here can be relied upon to exist as soon as the object has been
constructed.

=head3 open, high, low, close, volume

These hashes are indexed by date and return the appropriate value for that date.  The volume hash is not used when
C<dates_by> is set to months.

=head3 lx

This hash, indexed by date, returns the logical x coordinate for that date.

=head3 dates

This array is a list of known dates indexed by the logical x coordinate.  It is the inverse to lx, where

    $x    = $s->{lx}{$date};
    $date = $s->{dates}[$x];
    
=head2 lines

Function data is stored in this hash, first keyed by the chart where the function belongs - one of prices,
volumes, cycles or signals.  Each of these are in turn sub-hashes keyed by a line id.  See <add_line> for details
of the data stored.

Example

A function line with two points on the prices graph would be entered thus.

    my $s = new Finance::Shares::Sample(...);
    
    my $data = { 
	'2002-01-11' => 850,
	'2002-03-28' => 991,
    };
    $s->add_line('prices', 'my_trend', $data, 'My Trend');

It would be held within the Sample object thus.

    $s->{lines}{prices}{my_trend}{data}{2002-01-11} = 850;
                                       {2002-03-28} = 991;

=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my $opt = {};
    if (@_ == 1) { $opt = $_[0]; } else { %$opt = @_; }
    
    my $o = {};
    bless( $o, $class );
    $o->{opt} = $opt;
    
    $o->{lines}  = {};

    ## option defaults
    $o->{stock}  = defined($opt->{symbol}) ? $opt->{symbol} : 'HPQ';
    $o->{end}    = defined($opt->{end_date})   ? $opt->{end_date}   : today_as_string();
    $o->{start}  = defined($opt->{start_date}) ? $opt->{start_date} : increment_date(today_as_string(), -1);
    $o->{dtype}  = defined($opt->{dates_by})   ? $opt->{dates_by}   : 'days';

    ## fetch and process data
    carp "'source' must be specified\n" unless defined($opt->{source});
    my $type = ref($opt->{source});
    CASE: {
	if ($type eq 'Finance::Shares::MySQL') {
	    $o->{db} = $opt->{source};
	    $o->fetch(%$opt);
	    last CASE;
	}
	if ($type eq 'HASH') {
	    $o->{db} = new Finance::Shares::MySQL( $opt->{source} );
	    $o->fetch(%$opt);
	    last CASE;
	}
	if ($type eq 'ARRAY') {
	    $o->from_array( $opt->{symbol}, $opt->{source} );
	    last CASE;
	}
	if (not $type) {
	    $o->from_csv( $opt->{symbol}, $opt->{source} );
	    last CASE;
	}
    }
   
    ## finish
    croak "Finance::Shares::Sample has no data\nStopped" unless $o->{close} and %{$o->{close}};
    
    return $o;
}

=head2 new( [options] )

C<options> can be a hash ref or a list of hash keys and values.  

C<source> and C<symbol> must be specified, with C<start_date> and C<end_date> also required if the source is
a mysql database.

Recognized keys are:

=head3 source

This can be a Finances::Shares::MySQL object or a hash ref holding options suitable for creating one.
Alternatively it may be the name of a CSV file or an array ref holding similar data.

Example 1

Using an existing MySQL object.

    my $db = new Finance::Shares::MySQL;	    
    my $ss = new Finance::Shares::Sample (
		source => $db,
	    );

Example 2

Creating our own MySQL connection.

    my $ss = new Finance::Shares::Sample (
		source => {
		    user     => 'wally',
		    password => '123jiM',
		    database => 'London',
		},
	    );

Several attempts (see C<tries> below) are made to fetch the data from the internet.  Then the
data is extracted from the MySQL database, filtered according to C<dates_by> and stored as date, price and volume
data.

The CSV file is read and converted to price and/or volume data, as appropriate.  Files downloaded from !Yahoo
Finance need filtering to change the dates into the YYYY-MM-DD format.  Alternatively, a script, F<fetch_csv> is
provided in the Finance::Shares directory.  The comma seperated values are interpreted by Text::CSV_XS and so are
currently unable to tolerate white space.  See the C<array> option for how the field contents are handled.
Optionally, the directory may be specified seperately.

Example 3

    my $ss = new Finance::Shares::Sample (
		source => 'quotes.csv',
		directory => '~/shares',
	    );

If C<source> is an array ref it should point to a list of arrays with fields date, open, high, low, close and volume.

Example 4

    my $data = [
    ['2002-08-01',645.13,645.13,586.00,606.36,33606236],
    ['2002-08-02',574.75,620.88,558.00,573.00,59618288],
    ['2002-08-05',589.88,589.88,560.11,572.42,20300730],
    ['2002-08-06',571.89,599.00,545.30,585.92,26890880],
    ['2002-08-07',565.11,611.00,560.11,567.11,24977940] ];
    
    my $ss = new Finance::Shares::Sample ( 
		source => $data,
	    );

Three formats are recognized:

    Date, Open, High, Low, Close, Volume
    Date, Open, High, Low, Close
    Date, Volume

Examples

    [2001-04-26,345,400,300,321,12345678],
    [2001-04-27,234.56,240.00,230.00,239.99],
    [2001-04-28, 987654],

The four price values are typically decimals and the volume is usually an integer in the millions.

=head3 dates_by

Control how the data are stored.  Suitable values are 'days', 'weeks' or 'months'.  For I<weeks> or I<months> the
average price and volume data is given under the last known day.  (Default: 'days')

=head3 end_date

The last day of price data, in YYYY-MM-DD format.  Only used if the data is fetched using
L<Finance::Shares::MySQL>.  See L<fetch>.
	    
=head3 symbol

The market abbreviation for the stock as used by Yahoo.  Non-US codes should have a suffix indicating the stock
exchange (e.g. BSY.L for BSkyB on the London Stock Exchange).  

=head3 mode

Determines how the stock quotes are obtained if Finance::Shares::MySQL is used.  Suitable values are 'online',
'offline' and 'cache'.  (Default: 'cache')

=head3 start_date

The first day of price data, in YYYY-MM-DD format.  Only used if the data is fetched using
L<Finance::Shares::MySQL>.  See L<fetch>.

=cut

sub add_line {
    my ($o, $graph, $lineid, $data, $key, $style, $show) = @_;
    croak "No line type\nStopped" unless $graph;
    croak "No line id\nStopped" unless $lineid;
    croak "No data for price line\nStopped" unless $data;
    croak "No key for price line\nStopped" unless $key;
    $show = 1 unless defined $show;
    #warn "Sample: add_line($graph, $lineid, $data, $key, $style, $show)\n";
    return $o->{lines}{$graph}{$lineid} = { data => $data, key => $key, style => $style, shown => $show };
}

=head2 add_line( graph, lineid, data, key [, style [, shown ]] )

=over 8

=item graph

The graph where the line should appear, one of 'prices', 'volumes', 'cycles' or 'signals'.

=item lineid

A string uniquely identifying the line.

=item data

A hash ref of values indexed by date.

=item key

The text to be shown next with the style in the Price Key box to the right of the chart.

=item style

This can either be a PostScript::Graph::Style object or a hash ref holding options for one.

=item shown

True if to be drawn, false otherwise.

=back

Add a line to the price chart to be drawn in the style specified identified by some key text.  The data is stored
as a hash with the following keys:

    data    A hash of numbers keyed by YYYY-MM-DD dates.
    shown   True if the line is to be drawn on a chart.
    style   A hash or PostScript::Graph::Style object.
    key	    A string associated with the style in the Key.

Example

    my $s = new Finance::Shares::Sample(...);
    $s->add_line('cycles', 'my_line', $data, 'My Line');

then

    $s->{lines}{cycles}{my_line}{key} == 'My Line';
    
=cut

sub value {
    my $o = shift;
    croak "No Finance::Shares::Sample object" unless ref($o) eq 'Finance::Shares::Sample';
    my %a = (
	strict	=> 0,
	shown	=> 1,
	graph	=> 'prices',
	value	=> 0,
	@_);
	
    my $id = line_id('value', $a{value});
    my $key = "$a{value}";
    my $data = {
	$o->{start} => $a{value},
	$o->{end}   => $a{value},
    };

    $o->add_line( $a{graph}, $id, $data, $key, $a{style}, $a{shown} );
    return $id;
 }

=head2 value( options )

Produce a comparison line for a fixed y value.

C<options> are in key/value format using the following keys.

=over 8

=item strict

If 1, return undef if the average period is incomplete.  If 0, return the best value so far.  (Default: 0)

=item shown

A flag controlling whether the function is graphed.  0 to not show it, 1 to add the line to the named C<graph>.
(Default: 1)

=item graph

A string indicating the graph for display: one of prices, volumes, cycles or signals.  (Default: 'prices')

=item value

The Y value indicating the line.

=back

Like all function methods, this returns the line identifier.

=cut
=head1 ACCESS METHODS

See L<DESCRIPTION> for the data items that are directly available.

=cut

sub id {
    my $o = shift;
    return line_id($o->{stock}, $o->{start}, $o->{dtype}, $o->{end});
}

=head2 id()

Return a string used to identify the sample.

=cut

sub start_date {
    return shift->{start};
}

=head2 start_date()

Returns date of first quote in YYYY-MM-DD format.

=cut

sub symbol {
    return shift->{stock};
}

=head2 symbol()

Returns the !Yahoo stock code as given to B<new()>.

=cut

sub end_date {
    return shift->{end};
}

=head2 end_date()

Returns date of last quote in YYYY-MM0DD format.

=cut

sub dates_by {
    return shift->{dtype};
}

=head2 dates_by()

Return a string indicating how the dates are spread.  One of 'data', 'days', 'workdays', 'weeks', 'months'.

=cut

sub known_lines {
    my ($o, @graphs) = @_;
    @graphs = qw(prices volumes cycles signals) unless @graphs;
    my @ids;
    foreach my $graph (@graphs) {
	foreach my $line (keys %{$o->{lines}{$graph}}) {
	    push @ids, $line;
	}
    }
    return wantarray ? @ids : \@ids;
}

=head2 known_lines( [ graph(s) ] )

Returns a list of line identifiers valid for the specified graphs, zero or more of prices, volumes, cycles or
signals.  If none are specified, all known lines are returned.

=cut

### SUPPORT METHODS

sub fetch {
    my ($o, %opt) = @_;
    my @rows = $o->{db}->fetch( %opt );
    $o->prepare_dates(\@rows) if (@rows);
}

sub from_csv {
    my ($o, $symbol, $file, $dir) = @_;
    my @data;
    my $csv = new Text::CSV_XS;
    open(INFILE, "<", $file) or die "Unable to open \'$file\': $!\nStopped";
    while (<INFILE>) {
	chomp;
	my $ok = $csv->parse($_);
	if ($ok) {
	    my @row = $csv->fields();
	    push @data, [ @row ] if (@row);
	}
    }
    close INFILE;

    $o->from_array( $symbol, \@data );
}
sub from_array {
    my ($o, $symbol, $data) = @_;
    die "Array required\nStopped" unless (defined $data);
    $o->{stock} = $symbol;

    $o->prepare_dates( $data );
}


sub prepare_dates {
    my $o    = shift;
    my $data = shift;
    my $dtype = $o->{dtype};
   
    ## remove any headings from data
    my $number = qr/^\s*[-+]?[0-9.]+(?:[Ee][-+]?[0-9.]+)?\s*$/;
    unless ($data->[0][1] =~ $number) {
	my $row = shift(@$data);
    }
    @$data = sort { $a->[0] cmp $b->[0] } @$data;
    my @first = ymd_from_string( $data->[0][0] );
    my @last  = ymd_from_string( $data->[$#$data][0] );

    ## extract data
    my (%open, %high, %low, %close, %volume);
    foreach my $row (@$data) {
	my ($date, $o, $h, $l, $c, $v) = @$row;
	$open{$date} = $o;
	$high{$date} = $h;
	$low{$date} = $l;
	$close{$date} = $c;
	$volume{$date} = $v if (defined $v);
    }

    ## process dates
    my ($endday, $knowndate) = (0);
    my @prev = (0, 0, 0);
    my ($tdow, $tday, $tmonth, $tyear);
    my ($topen, $tclose, $thigh, $tlow, $tvolume, $total);
    my $ndays  = days_difference(@first, @last);
    my ($x, %lx, @dates) = 0;
    my $pmin = $highest_int;
    my $pmax = $lowest_int;
    my $vmin = $highest_int;
    my $vmax = $lowest_int;
    foreach my $date (sort keys %close) {
	my @ymd     = ymd_from_string($date);
	my ($year, $month, $day) = @ymd;
	my $dow     = day_of_week(@ymd);
	my $weekday = ($dow >= 1 and $dow <= 5);
	my $known   = $close{$date};
	
	CASE: {
	    ## weeks
	    if ($dtype eq 'weeks') {
		# Each weeks data accumulates until the next week begins.
		# So at the start of each week, the previous week's data are
		# recorded under the last recorded weekday (usually Friday).
		if ($weekday) {
		    # $dow: 1=Monday .. 7=Sunday
		    if ($dow >= $endday) { 
			if ($known) {
			    # add values to totals for week
			    $total++;
			    $topen   += $open{$date};
			    $thigh   += $high{$date};
			    $tlow    += $low{$date};
			    $tclose  += $close{$date};
			    $tvolume += $volume{$date};
			    # remove days data
			    delete $open{$date};
			    delete $high{$date};
			    delete $low{$date};
			    delete $close{$date};
			    delete $volume{$date};
			    # note this as last date known so far
			    $knowndate = $date;
			}
			$tdow=$dow; $tday=$day; $tmonth=$month; $tyear=$year;
		    } else {
			# Monday
			if (defined $knowndate) { 
			    # put last weeks totals into last known date
			    $open{$knowndate}   = $topen/$total;
			    $high{$knowndate}   = $thigh/$total;
			    $low{$knowndate}    = $tlow/$total;
			    $close{$knowndate}  = $tclose/$total;
			    $volume{$knowndate} = $tvolume/$total;
			    push @dates, $knowndate;
			    $lx{$knowndate} = $x++;
			    $pmin = $low{$knowndate}  if $low{$knowndate}  < $pmin;
			    $pmax = $high{$knowndate} if $high{$knowndate} > $pmax;
			    if ($volume{$knowndate}) {
				$vmin = $volume{$knowndate} if $volume{$knowndate} < $vmin;
				$vmax = $volume{$knowndate} if $volume{$knowndate} > $vmax;
			    }
			}
			# clear for a new week
			if ($known) {
			    $total   = 1;
			    $topen   = $open{$date};
			    $thigh   = $high{$date};
			    $tlow    = $low{$date};
			    $tclose  = $close{$date};
			    $tvolume = $volume{$date};
			    # remove days data
			    delete $open{$date};
			    delete $high{$date};
			    delete $low{$date};
			    delete $close{$date};
			    delete $volume{$date};
			} else {
			    $topen = $thigh = $tlow = $tclose = $tvolume = $total = 0;
			}
			$knowndate  = undef;
		    }
		    $endday = $dow;
		}
		last CASE;
	    }

	    ## months
	    if ($dtype eq 'months') {
		# Each months data accumulates until the next month begins.
		if ($weekday) {
		    if ($day >= $endday) {
			if ($known) {
			    $total++;
			    $topen   += $open{$date};
			    $thigh   += $high{$date};
			    $tlow    += $low{$date};
			    $tclose  += $close{$date};
			    $tvolume += $volume{$date};
			    delete $open{$date};
			    delete $high{$date};
			    delete $low{$date};
			    delete $close{$date};
			    delete $volume{$date};
			    $knowndate = $date;
			}
			$tdow=$dow; $tday=$day; $tmonth=$month; $tyear=$year;
		    } else {
			# 1st working day of new month
			if (defined $knowndate) { 
			    $open{$knowndate}   = $topen/$total;
			    $high{$knowndate}   = $thigh/$total;
			    $low{$knowndate}    = $tlow/$total;
			    $close{$knowndate}  = $tclose/$total;
			    $volume{$knowndate} = $tvolume/$total;
			    push @dates, $knowndate;
			    $lx{$knowndate} = $x++;
			    $pmin = $low{$knowndate}  if $low{$knowndate}  < $pmin;
			    $pmax = $high{$knowndate} if $high{$knowndate} > $pmax;
			    if ($volume{$knowndate}) {
				$vmin = $volume{$knowndate} if $volume{$knowndate} < $vmin;
				$vmax = $volume{$knowndate} if $volume{$knowndate} > $vmax;
			    }
			}
			# clear for a new month
			if ($known) {
			    $total   = 1;
			    $topen   = $open{$date};
			    $thigh   = $high{$date};
			    $tlow    = $low{$date};
			    $tclose  = $close{$date};
			    delete $open{$date};
			    delete $high{$date};
			    delete $low{$date};
			    delete $close{$date};
			    delete $volume{$date};
			} else {
			    $topen = $thigh = $tlow = $tclose = $total = 0;
			}
			$knowndate  = undef;
		    }
		    $endday = $day;
		}
		last CASE;
	    }

	    ## days - default CASE
	    push @dates, $date;
	    $lx{$date} = $x++;
	    $pmin = $low{$date}  if $low{$date}  < $pmin;
	    $pmax = $high{$date} if $high{$date} > $pmax;
	    if ($volume{$date}) {
		$vmin = $volume{$date} if $volume{$date} < $vmin;
		$vmax = $volume{$date} if $volume{$date} > $vmax;
	    }
	}
    }

    ## finish off
    if (defined $knowndate) { 
	$open{$knowndate}  = $topen/$total;
	$high{$knowndate}  = $thigh/$total;
	$low{$knowndate}   = $tlow/$total;
	$close{$knowndate} = $tclose/$total;
	$volume{$knowndate} = $tvolume/$total;
	push @dates, $knowndate;
	$lx{$knowndate} = $x++;
	$pmin = $low{$knowndate}  if $low{$knowndate}  < $pmin;
	$pmax = $high{$knowndate} if $high{$knowndate} > $pmax;
	if ($volume{$knowndate}) {
	    $vmin = $volume{$knowndate} if $volume{$knowndate} < $vmin;
	    $vmax = $volume{$knowndate} if $volume{$knowndate} > $vmax;
	}
    }

    ## Define data
    $o->{open}   = \%open;
    $o->{high}   = \%high;
    $o->{low}    = \%low;
    $o->{close}  = \%close;
    $o->{volume} = \%volume if %volume;
    $o->{lx}     = \%lx;	# YYYY-MM-DD => x coordinate on chart; keys give definitive list of dates
    $o->{dates}  = \@dates;	# array where each index x => YYYY-MM-DD
    $o->{start}  = $dates[0];
    $o->{end}    = $dates[$#dates];
    $o->{lines}{prices}{open}    = { shown => 0, key => 'Opening price', data => \%open };
    $o->{lines}{prices}{high}    = { shown => 0, key => 'Highest price', data => \%high };
    $o->{lines}{prices}{low}     = { shown => 0, key => 'Lowest price',  data => \%low };
    $o->{lines}{prices}{close}   = { shown => 0, key => 'Closing price', data => \%close };
    $o->{lines}{volumes}{volume} = { shown => 0, key => 'Volume',        data => \%volume } if %volume;

    ## Define min/max
    $o->{prices}{min} = $pmin;
    $o->{prices}{max} = $pmax;
    $o->{volumes}{min} = ($vmin != $highest_int) ? $vmin : 0;
    $o->{volumes}{max} = ($vmax != $lowest_int)  ? $vmax : 0;
    my $margin = 100 * $points_margin;
    $o->{cycles}{min} = -100 + $margin;
    $o->{cycles}{max} = 100 - $margin;
    $o->{signals}{min} = $margin;
    $o->{signals}{max} = 100 - $margin;}

sub previous_date {
    my ($o, $date) = @_;
    my $x = $o->{lx}{$date};
    my $prev = $o->{dates}[--$x] if $x;
    return $prev || '';	
}

sub chart {
    my ($o, $chart) = @_;
    $o->{chart} = $chart if $chart;
    return $o->{chart};
}

### SUPPORT FUNCTIONS

sub line_id {
    no warnings;
    my $cmd = shift;
    return $cmd unless @_;
    my $args = join(',', @_);
    return "$cmd($args)";
}

sub function {
    my ($hash, $name, @args) = @_;
    if (defined $name) {
	my $fn = $hash->{$name};
	no warnings;
	#warn "Sample::function $name(", join(',', @args), ")\n";
	if (defined $fn) {
	    my $res;
	    eval {
		$res = &$fn(@args);
	    };
	    croak "error in $name()\n $@" if $@;
	    return $res;
	}
    }
    return undef;	    
}

sub choose_line {
    my ($o, $graph, $id, $original) = @_;

    my $full = $o->{lines}{$graph}{"_$id"};
    return $full if $full;
    
    my $given = $o->{lines}{$graph}{$id};
    my $nquotes = @{$o->{dates}};
    return undef unless $given;
    return $given if $original;
    return $given if keys(%{$given->{data}}) >= $nquotes;

    return $o->interpolate($graph, $id);
}
# Interpolated lines have '_' prepended, and are prefered for tests.
# Note that the hash values for both keys might point to the same data.

=head2 choose_line( graph, line [, original ] )

Return the data for the identified line.  The data may be checked and any missing values interpolated.

=over 8

=item graph

One of prices, volumes, cycles or signals.

=item line

A string identifying the line.

=item original

If true, the original (not interpolated) line is returned.

=back

Returns undef if there is no such line.  B<choose_line> therefore indicates whether the line exists or not (best
called with original=1 for this).

=cut

sub interpolate {
    my ($o, $graph, $id) = @_;
    my $given = $o->{lines}{$graph}{$id};
    my $gdata = $given->{data};
    
    my $res = {};
    if ($gdata and values(%$gdata) == @{$o->{dates}}) {
	$res = $gdata;
    } else {
	my ($px, $nx);
	foreach my $x (0 .. $#{$o->{dates}}) {
	    my $date = $o->{dates}[$x];
	    if ($gdata->{$date}) {
		$px = $x;
		$res->{$date} = $gdata->{$date};
	    } else {
		undef $nx;
		foreach my $x1 ($x .. $#{$o->{dates}}) {
		    my $date1 = $o->{dates}[$x1];
		    $nx = $x1, last if $gdata->{$date1};
		}
		if (defined $px and defined $nx) {
		    my $dn = $nx - $x;
		    my $dp = $x - $px;
		    my $vn = $gdata->{ $o->{dates}[$nx] };
		    my $vp = $gdata->{ $o->{dates}[$px] };
		    $res->{$date} = ($vp*$dn + $vn*$dp)/($dp+$dn);
		}
	    }
	}
    }
	
    $o->{lines}{$graph}{"_$id"} = {
	data  => $res,
	key   => $given->{key},
	style => $given->{style},
	shown => 0,
    };
}

=head1 DATE FUNCTIONS

There are three types of dates here.  A 'days' value is the number of days from some arbitrary day zero.  A 'date'
is a string in YYYY-MM-DD format while 'ymd' refers to an array holding a year, month and day such as (2002, 12,
31).  See L<SYNOPSIS> for all the functions.

=cut

sub today_as_string () {
    return sprintf("%04d-%02d-%02d", Today());

}

=head2 today_as_string

Return today's date in YYYY-MM-DD format.

=cut

sub string_from_ymd (@) {
    return sprintf("%04d-%02d-%02d", @_);
}

=head2 string_from_ymd( year, month, day )

Convert the numeric representation of year, month and day into a YYYY-MM-DD date.

=cut

sub ymd_from_string ($) {
    my $string = shift;
    return ($string =~ /(\d{4})-(\d{2})-(\d{2})/);
}

=head2 ymd_from_string( date )

Convert a YYYY-MM-DD date into an array of numeric values in the form:

    (year, month, day)

=cut

sub increment_days {
    my ($y, $m, $d, $inc) = @_;
    return Add_Delta_Days($y, $m, $d, $inc);
}

=head2 increment_days( year, month, day, inc_days )

Add C<inc_days> to the date and return as a year-month-day array.

=cut

sub increment_date ($$) {
    my ($string, $days) = @_;
    my @date = ymd_from_string( $string );
    my @newdate = Add_Delta_Days( @date, $days );
    return string_from_ymd( @newdate );
}

=head2 increment_date( date, days )

Add the number of days given to the YYYY-MM-DD date and return the new date in YYYY-MM-DD format.

=cut


sub days_difference {
    my ($y1, $m1, $d1, $y2, $m2, $d2) = @_;
    return Delta_Days($y1, $m1, $d1, $y2, $m2, $d2);
}

=head2 days_difference( year1, month1, day1, year2, month2, day2 )

Return the number of days between the two dates

=cut

sub day_of_week {
    return Day_of_Week(@_);
}

=head2 day_of_week( year, month, day )

Returns 1=Monday, ... 7=Sunday.

=cut

=head1 BUGS

Please report those you find to the author.

=head1 AUTHOR

Chris Willmot, chris@willmot.org.uk

=head1 SEE ALSO

L<Finance::Shares::MySQL>,
L<Finance::Shares::Chart> and
L<Finance::Shares::Model>.

There is also an introduction, L<Finance::Shares::Overview> and a tutorial beginning with
L<Finance::Shares::Lesson1>.

=cut

1;

