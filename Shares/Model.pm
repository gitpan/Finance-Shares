package Finance::Shares::Model;
our $VERSION = 0.10;
use strict;
use warnings;
use Carp;
use PostScript::File	     0.13;
use Finance::Shares::Sample  0.11 qw(line_id function);

our %testfunc;
$testfunc{gt} = \&test_gt;
$testfunc{lt} = \&test_lt;
$testfunc{ge} = \&test_ge;
$testfunc{le} = \&test_le;
$testfunc{eq} = \&test_eq;
$testfunc{ne} = \&test_ne;

our %sigfunc;
$sigfunc{mark_buy}    = \&signal_mark_buy;
$sigfunc{mark_sell}   = \&signal_mark_sell;
$sigfunc{print}       = \&signal_print;
$sigfunc{print_value} = \&signal_print_value;
$sigfunc{custom}      = \&signal_custom;

our %testname;
$testname{gt} = 'above';
$testname{lt} = 'below';
$testname{ge} = 'above or touching';
$testname{le} = 'below or touching';
$testname{eq} = 'same as';
$testname{ne} = 'different from';

our $points_margin = 0.02;	# logical 0/1 is mark_range -/+ points_margin * mark_range

=head1 NAME

Finance::Shares::Model - Apply tests to stock quotes

=head1 SYNOPSIS

Most usage requires at least one Sample with some function lines calculated on it's data.  The functions and data
are compared to produce a test line and possibly trigger signals.

    use Finance::Shares::Model;
    use Finance::Shares::Sample;
    use Finance::Shares::Bands;
    use Finance::Shares::Chart;

    my $fsm = new Finance::Shares::Model;

    my $fss = new Finance::Shares::Sample(...);
    $fsm->add_sample( $fss );

    $fsm->add_signal('mark_buy', undef, {
	graph => 'volumes',
	line  => 'volume',
	key   => 'above envelope',
	style => {
	    point => {
		color => [1, 0, 0],
		shape => 'circle',
		size  => 15,
	    },
	},
    });

    my ($high, $low) = $fss->envelope(
	graph => 'prices', line => 'close',
	percent => 3,
    );

    $fsm->test(
	graph1 => 'prices', line1 => $high,
	graph2 => 'prices', line2 => 'high',
	test   => 'ge',
	graph  => 'signals',
	signal => [ 'mark_buy' ],
    );

    my $fsc = new Finance::Shares::Chart(
	sample => $fss,
    );
    $fsc->output($filename);
       
This pseudo-example draws a circle around the volume where a day's highest price is more than 3% above the
previous closing price.
	
=head1 DESCRIPTION

This module provides the testing enviroment for the Finance::Shares suite.  The Model brings a group of
L<Finance::Shares::Samples> together and applies tests to them all.  The tests usually rely on functions from other
modules such as L<Finance::Shares::Averages>, and the results are usually seen using L<Finance::Shares::Chart>.

Unusually, the Finance::Shares::Model constructor does nothing.  However, nothing will happen until B<add_sample>
has been called at least once.  The tests are applied to all samples, which don't need to have anything in common
with each other.  However, if the date ranges are completely different it would probably be better to run three
seperate models.  This is because the Model's date range covered by each of the tests is made from all dates in
all samples.

The tests currently available are:

    gt	    1st line moves above 2nd
    lt	    moves below
    ge	    moves above or touches
    le	    moves below or touches
    eq	    touches
    ne	    doesn't touch  

The tests produce data lines in the standard format.  This means that data, functions and tests can be used
interchangeably.  They can all be graphed (or hidden).  Wherever a 'line' is expected, it can be a data, function
or test line.  I think a circular reference is not possible because of the declaration order, but it would be
a Very Bad Thing (TM) so be aware of the possibility.

These results lines are analog in that they can take a range of values.  Indeed they can be made to decrease over
time.  But they represent a B<state> or level at any particular time.  Signals, on the other hand, are a form of
output that is inherently digital - either it has been invoked or it hasn't.  All tests can have zero or more
signals associated with them which are invoked when some critical B<change> of state happens, like when one line
crosses over another.  Currently the following signals are available:

=over 14

=item mark_buy

Places a mark on a graph.

=item mark_sell

Places a mark on a graph.

=item print_value

Write signal results to a file.

=item print

Print a message on the console.

=item custom

Invoke a user defined callback.

=back

=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my $opt = {};
    if (@_ == 1) { $opt = $_[0]; } else { %$opt = @_; }
  
    my $o = {};
    bless( $o, $class );
    
    $o->{samples} = {};
    $o->{start} = '9999-99-99';
    $o->{end}   = '0000-00-00';
    
    $o->{sigfns} = {};

    return $o;
}

=head2 new

There are no options.  All settings are given using B<add_sample>, B<add_signal>, B<test> and B<output>.

=cut

=head1 MAIN METHODS

=cut

sub add_sample {
    my ($o, $s) = @_;
    croak unless $s->isa('Finance::Shares::Sample');
    my $start = $s->start_date();
    my $end   = $s->end_date();
    my $id    = $s->id();
    $o->{samples}{$id} = $s;
    $o->{start} = $start if $start lt $o->{start};
    $o->{end}   = $end   if $end   gt $o->{end};

    return $s;
}

=head2 add_sample( sample )

This adds stock quote data to the model.  C<sample> must be a L<Finance::Shares::Sample> object.  The results of
the tests are written back to the sample which would typically be displayed on a L<Finance::Shares::Chart>.

Multiple samples can be added.  These might be for the same stock sampled over days, weeks and months, or for
different stocks and different dates.  Bear in mind that all tests are conducted on all dates, so it makes sense
to keep the date ranges as similar as possible.

=cut

sub add_signal {
    my ($o, $signal, $obj, @args) = @_;
    if ($sigfunc{$signal}) {
	$o->{sigfns}{$signal} = [] unless defined $o->{sigfns}{$signal};
	my $sf = $o->{sigfns}{$signal};
	push @$sf, [ $obj, @args ];
    } else {
	croak "Unknown signal function type '$signal'\n";
    }
}

=head2 add_signal( signal, [ object [, args ]] )

Register a callback function which will be invoked when some test evaluates 'true'.

=over 8

=item signal

This must be a known signal name, see L</SIGNALS>.

=item object

Use 'undef' here for those signals that need to use the Finance::Shares::Sample, such as 'mark_buy'.
When registering B<print>, this is the message to print and when registering a B<custom> function,
this is the function reference.

=item args

Any arguments that will be passed to the signal function.

=back

See the individual signal handling methods for the arguments that signal requires.

=cut

sub test {
    my $o = shift;
    my %a = (
	graph1	=> 'prices',	line1	=> 'close',
	#graph2	=> 'prices',	#line2	=> 'close',	# only defined when not unary test
	test	=> 'gt',	shown	=> 1,		style	=> {},
	weight	=> 100,		decay	=> 1,		ramp	=> 0,
	@_);

    my $id = $a{line};
    foreach my $s (values %{$o->{samples}}) {
	my ($base1, $base2);
	my $label = $a{key};
	$base1 = $s->choose_line($a{graph1}, $a{line1});
	die "No $a{graph1} line with id '$a{line1}'" unless $base1;
	die "Line '$a{line1}' has no key" unless $base1->{key};
	if($a{line2}) {
	    my $graph2 = $a{graph2};
	    $graph2 = $a{graph1} unless defined $graph2;
	    $base2 = $s->choose_line($graph2, $a{line2});
	    croak "No $graph2 line with id '$a{line2}'" unless $base2;
	    croak "Line '$a{line2}' has no key" unless $base2->{key};
	    $label = "$base1->{key} $testname{$a{test}} $base2->{key}" unless $label;
	    $id = line_id($a{test}, $a{graph1}, $a{line1}, $graph2, $a{line2}) unless $id;
	} else {
	    $label = "$testname{$a{test}} $base1->{key}" unless $label;
	    $id = line_id($a{test}, $a{graph1}, $a{line1}) unless $id;
	}
	
	my $graph = $a{graph};
	my ($min, $max);
	$graph = $a{graph1} unless defined $graph;
	if ($graph eq 'signals') {
	    $min = 0;
	    $max = $a{weight};
	    $max = 100 if not $max or $max > 100;
	} else {
	    my $gmin = $s->{$graph}{min};
	    my $gmax = $s->{$graph}{max};
	    my $margin = ($gmax - $gmin) * $points_margin;
	    $min = $gmin - $margin;
	    $max = $gmax + $margin;
	}
	$a{decay} = 1 unless defined $a{decay};
	$a{decay} = 0 if $a{decay} < 0;
	$a{ramp}  = 0 unless defined $a{ramp};
	my $data = ensure_common_values( $base1, $base2 );
	my $res = function(\%testfunc,$a{test}, 
			    $o, $data, (%a, sample => $s, line1 => $base1, line2 => $base2, min => $min, max => $max) );
	$s->add_line($graph, $id, $res, $label, $a{style}, $a{shown}) if $res;
    }
     return $id;
}

=head2 test( options )

A test is added to the model and the resulting line added to each Sample.  Signals are invoked when a date is
encountered that passes the test.  Tests may be binary (working on two lines) or unary (just working on one).

The method returns the identifier string for the resulting data line.

C<options> are passed as key => value pairs, with the following as known keys.

=over 8

=item graph1

The graph holding C<line1>.  Must be one of 'prices', 'volumes', 'cycles' or 'signals'.

=item line1

A string identifying the only line for a unary test or the first line for a binary test.

=item graph2

The graph holding C<line2>.  Must be one of 'prices', 'volumes', 'cycles' or 'signals'.  Defaults to C<graph1>.

=item line2

A string identifying the second line for a binary test.  For a unary test this must be undefined.

=item test

The name of the test to be applied, e.g 'gt' or 'lt'.  Note this is a string and not a function reference.

=item shown

True if the results should be shown on a graph.

=item style

If present, this should be either a PostScript::Graph::File object or a hash ref holding options for creating one.

=item graph

The destination graph, where C<line> will be displayed.  Must be one of 'prices', 'volumes', 'cycles' or 'signals'.

If not specified, C<graph1> is used.  This is a little odd as the scales are usually meaningless.  However, as
mostly the result is an on-or-off function, the line is suitably scaled so the shape is clear enough.

=item line

An optional string identifying the results data in case you wish to refer to them in another test.  Provided for
completeness, but it is much better to use the internal one returned by this method.

=item key

The string which will appear in the Key panel identifying the test results.

=item weight

How important the test should appear.  Most tests implement this as the height of the results line.

=item decay

If the condition is met over a continuous period, the results line can be made to decay.  This factor is
multiplied by the previous line value, so 0.95 would produce a slow decay while 0 signals only the first date in
the period.

=item ramp

An alternative method for conditioning the signal line.  This amount is added to the signal value with each
period.

=item signal

This should be one or more of the signals registered with this model.  It can either be a single name or an array
ref holding a list of names.

=back

The results line would typically be shown on the 'signals' graph.  Most tests are either true or false, so the
line is flat by default.  The line can be conditioned, however, so its value changes over time.
Here are some examples of how the relevant parameters interact.

Example 1

    decay   => 0.5,
    ramp    => 0,

An exponential decay, halving with each period.

    decay   => 0.95,
    ramp    => 0,

A much shallower decaying curve.

    weight => 100,
    decay  => 1,
    ramp   => -20,

A straight line decline which disappears after five days.

    weight => 100,
    decay  => 1.983,
    ramp   => -99,

An inverted curve with the first 5 days scoring more than 85 then dropping rapidly to 0 after 7 days.

=cut

sub output {
    my $o = shift;
    my $pf = shift;
    my ($filename, $dir);
    if ($pf and (ref($pf) eq 'HASH' or $pf->isa('PostScript::File'))) {
	($filename, $dir) = @_;
    } else {
	$dir = shift;
	$filename = $pf;
	$pf = {};
    }

    if (ref($pf) eq 'HASH') {
	$pf->{paper}     = 'A4' unless (defined $pf->{paper});
	$pf->{landscape} = 1    unless (defined $pf->{landscape});
	$pf->{left}      = 36   unless (defined $pf->{left});
	$pf->{right}     = 36   unless (defined $pf->{right});
	$pf->{top}       = 36   unless (defined $pf->{top});
	$pf->{bottom}    = 36   unless (defined $pf->{bottom});
	$pf->{errors}    = 1    unless (defined $pf->{errors});
	$pf = new PostScript::File( $pf );
    }
    croak "No PostScript::File object\n" unless ($pf and $pf->isa('PostScript::File'));
	
    my $pages = 0;
    foreach my $s (values %{$o->{samples}}) {
	my $chart = $s->chart();
	next unless $chart and $chart->isa('Finance::Shares::Chart');
	$pf->newpage() if $pages++;
	$chart->build_chart($pf);
    }
	
    return $pf->output($filename, $dir);
}

=head2 output( [psfile,] [filename [, directory]] )

C<psfile> can either be a L<PostScript::File> object, a hash ref suitable for constructing one or undefined.

The charts are constructed and written out to the PostScript file.  A suitable suffix (.ps, .epsi or .epsf) will
be appended to C<filename>.

If no filename is given, the PostScript text is returned.  This makes handling CGI requests easier.

Examples

    my $file = $fsm->output();

The PostScript is returned as a string.  The PostScript::File object has been constructed using defaults which
produce a landscape A4 page.

    $fsm->output('myfile');

The default A4 landscape page(s) is/are saved as F<myfile.ps>.

    my $pf = new PostScript::File(...);
    my $file = $fsm->output($pf);

PostScript is returned for printing using CGI.pm for example.  The pages are formatted according to the
PostScript::File parameters.  The same result would have been obtained had $pf been a hash ref.

    my $pf = new PostScript::File(...);
    $fsm->output($pf, 'shares/myfile', $dir);

The specially tailored page(s) is/are written to F<$dir/shares/myfile.ps>.

Note that it is not possible to print the charts individually once this has been called.  However, it is possible
to output them seperately to their own files, I<then> call this to output a file showing them all.

=cut

=head1 SIGNALS

Before they can be used signals must have been registered with the Model using B<add_signal>.
The name must then be given to B<test> as (part of) the B<signal> value.

Most parameters are given when it is registered, but the date of the signal is also passed to the handler.

=cut

sub signal_mark_buy {
    my ($s, $date, $p) = @_;
    croak 'Cannot mark buy signal: no date' unless defined $date;
    $p->{graph} = 'prices', $p->{line} = 'close' unless $p->{graph} and ($p->{line} or defined $p->{value});
    $p->{key} = 'buy signal' unless defined $p->{key};
    $p->{shown} = 1 unless defined $p->{shown};

    $p->{style} = {
	same => 0, 
	auto => 'none', 
	point => { 
	    shape => 'north',
	    size => 10,
	    y_offset => -12,
	    color => [0.5, 0.6, 1],
	    width => 2,
	},
    } unless defined $p->{style};
    
    my $value;
    my $graph = $p->{graph};
    if (defined $p->{value}) {
	$value = $p->{value};
    } else {
	my $vline = $s->choose_line($graph, $p->{line});
	croak "Cannot mark buy signal: line '$p->{line}' does not exist on $graph\n" unless defined $vline;
	$value = $vline->{data}{$date};
    }
    croak 'Cannot mark buy signal: no value' unless defined $value;
    my $id = '_mark_buy';
    
    my $buy = $s->choose_line( $graph, $id, 1 );
    $buy = $s->add_line( $graph, $id, {}, $p->{key}, $p->{style}, $p->{shown} ) unless defined $buy;
    
    $buy->{data}{$date} = $value;
    #warn "BUY: $date = $value\n";
}

=head2 mark_buy

A 'buy' point is drawn on a graph when the test evaluates 'true'.  The following parameters may be passed to
B<add_signal> within a hash ref.

Example

    $fsm->add_signal('mark_buy', undef, {
	graph => 'prices', 
	value => 440,
    });
    
=over 8

=item graph

One of prices, volumes, cycles or signals.

=item value

If present, this should be a suitable Y coordinate.  No bounds checking is done.

=item line

If no C<value> is given, the value may be obtained from the line identified by this string.

=item key

Optional string appearing in the Key panel.

=item style

An optional hash ref containing options for a PostScript::Graph::Style, or a PostScript::Graph::Style object.  It
should only have a B<point> group defined (line and bar make no sense).  (Default: blue arrow).

=item shown

Optional flag, true if the mark is to be shown (Default: 1)

=back

=cut

sub signal_mark_sell {
    my ($s, $date, $p) = @_;
    croak 'Cannot mark sell signal: no date' unless defined $date;
    $p->{graph} = 'prices', $p->{line} = 'close' unless defined $p->{graph} and defined $p->{line};
    $p->{key} = 'sell signal' unless defined $p->{key};
    $p->{show} = 1 unless defined $p->{show};

    $p->{style} = {
	same => 0, 
	auto => 'none', 
	point => { 
	    shape => 'south',
	    size => 10,
	    y_offset => 12,
	    color => [0.9, 0.6, 0.5],
	    width => 2,
	},
    } unless defined $p->{style};
    
    my $value;
    my $graph = $p->{graph};
    if (defined $p->{value}) {
	$value = $p->{value};
    } else {
	my $vline = $s->choose_line($graph, $p->{line});
	croak 'Cannot mark sell signal: no line' unless defined $vline;
	$value = $vline->{data}{$date};
    }
    croak 'Cannot mark sell signal: no value' unless defined $value;
    my $id = '_mark_sell';
    
    my $sell = $s->choose_line( $graph, $id, 1 );
    $sell = $s->add_line( $graph, $id, {}, $p->{key}, $p->{style}, $p->{show} ) unless defined $sell;
    
    $sell->{data}{$date} = $value;
    #warn "BUY: $date = $value\n";
}

=head2 mark_sell

Draws a 'sell point'.  See B<mark_buy>.

=cut

sub signal_print_value {
    my ($s, $date, $p) = @_;
    croak 'Cannot print value: no date' unless defined $date;
    my $value = '<undef>';
    if (defined $p->{value}) {
	$value = $p->{value};
    } elsif (defined $p->{graph} and defined $p->{line}) {
	my $vline = $s->choose_line($p->{graph}, $p->{line});
	croak 'Cannot mark sell signal: no line' unless defined $vline;
	$value = $vline->{data}{$date};
    }
    croak 'Cannot mark sell signal: no value' unless defined $value;

    my $msg = $p->{message};
    $msg = '' unless defined $msg;
    $msg =~ s/\$date/$date/g;
    $msg =~ s/\$value/$value/g;
    my $file = $p->{file};
    $file = \*STDOUT unless defined $file;
    print $file $msg, "\n";
} 

=head2 print_value

This is the heavy duty print signal.  See L</print> for a lighter weight one.

It prints a string to a file or to STDOUT when the test evaluates 'true'.
The following parameters may be passed to B<add_signal> within a hash ref.

Example 1

    $fsm->add_signal('print_value', undef, {
	    message => 'Volume is $value at $date', 
	    graph => 'volumes', line => 'volume',
	});

=over 8

=item message

This is the string that is output.  It may include C<$date> and C<$value>, which will be replaced with the date
and value for that signal.  Note that this should be given in single quotes or with the '$' signs escaped.  $date
and $value look like variables but are actually just placeholders.

=item graph

One of prices, volumes, cycles or signals.

=item value

If present, this should be a suitable Y coordinate.  No bounds checking is done.

=item line

If no C<value> is given, the value may be obtained from the line identified by this string.

=item file

If given, this should be an already open file handle.  It defaults to C<\*STDOUT>.

=back

Example 2
    
    my $fsm = new Finance::Shares::Model;
    
    my $sfile;
    open $sfile, '>>', 'signals.txt';
    
    $fsm->add_signal('print_value', undef, {
	message => '$date',
	file    => $sfile,
    });

    $fsm->test(
	graph1 => 'prices', line1 => 'close',
	graph1 => 'prices', line2 => 'open',
	test   => 'gt',
	signal => 'print_value',
    );

    close $sfile;

Here a list of dates are written to the file 'signals.txt' instead.
    
=cut


sub signal_print {
    my ($msg, $date) = @_;
    $msg = '' if not defined $msg or ref($msg);
    print "SIGNAL at $date", ($msg ? ": $msg" : ''), "\n";
}

=head2 print

This is the lightweight print signal.  See L</print_value> for a fuller featured one.

It prints a string to STDOUT when the test evaluates 'true'.

Register the signal like this:

    my $fsm = new Finance::Shares::Model;
    
    $fsm->add_signal('print', 'Some message');

or even
    
    $fsm->add_signal('print');

Note that this is slighty different from all the others - there is no C<undef> (the object placeholder).
    
=cut

sub signal_custom {
    my ($func, $date, @args) = @_;
    croak unless ref($func) eq 'CODE';
    &$func( $date, @args );
}

=head2 custom

Use this to register your own callbacks.  When your function is called, C<date> will always be the first
parameter, followed by any C<args> given here.  The format is as follows:

    $fsm->add_signal( 'custom', <coderef>, @args );
	
Example

    my $fss = new Finance::Shares::Sample(...);
    my $fsm = new Finance::Shares::Model;
    
    my $level = $fss->value(
	graph => 'volumes', value => 250000
    );

    sub some_func {
	my ($date, @args) = @_;
	...
    }
    
    $fsm->add_signal( 'custom', \&some_func, 
	3, 'blind', $mice );

    $fsm->test(
	graph1 => 'volumes', line1 => 'volume',
	graph1 => 'volumes', line2 => $level,
	test   => 'gt',
	signal => 'custom',
    );

Here &some_func will be be called with four parameters whenever the volume moves above 250000.

=cut

=head1 SUPPORT METHODS

=cut

sub signal {
    my ($o, $ss, $obj, $param) = @_;
    my $signals = ref($ss) eq 'ARRAY' ? $ss : [ $ss ];
    foreach my $signal (@$signals) {
	next unless $signal;
	my $sf = $o->{sigfns}{$signal};
	return unless ref($sf) eq 'ARRAY';
	foreach my $ar (@$sf) {
	    my ($org, @rest) = @$ar;
	    $org = $obj unless defined $org;
	    function( \%sigfunc,$signal, $org,$param,@rest );
	}
    }
}

=head2 signal( signal [, object [, param ]] )

All callbacks of the type indicated by C<signal> will be invoked.

=over 8

=item signal

This can be either a single signal name, or an array ref containing signal names.  Allowed names include:

    mark_buy
    mark_sell
    print
    custom

=item object

An object may be given when the signal was registered with B<add_signal>.  But if it was not, this will be the
first parameter passed instead.

=item param

The second parameter passed to the callback function.  Any number of arguments may be passed here as an array ref.

=back

Any other registered parameters are passed after C<param>.

=cut


sub test_gt {
    my ($o, $data, %a) = @_;					# See test for list of keys

    my $prev_comp;
    my $level = 0;
    my %res;
    foreach my $date (sort keys %$data) {
	my $comp = $data->{$date};
	if (defined $prev_comp and defined $comp) {
	    if ($prev_comp <= 0 and $comp > 0) {	# change this when copying
		$level = $a{max};
		$o->signal($a{signal}, $a{sample}, $date);
	    } elsif ($prev_comp > 0 and $comp <= 0) {	# change this when copying
		$level = $a{min} ;
	    } else {
		$level = condition_level( $level, \%a );
	    }
	}
	$level = $a{max} if $level > $a{max};
	$level = $a{min} if $level < $a{min};
	$prev_comp  = $comp;
	$res{$date} = $level;
    }

    return %res ? \%res : undef;
}

sub test_lt {
    my ($o, $data, %a) = @_;					# See test for list of keys

    my $prev_comp;
    my $level = 0;
    my %res;
    foreach my $date (sort keys %$data) {
	my $comp = $data->{$date};
	if (defined $prev_comp and defined $comp) {
	    if ($prev_comp >= 0 and $comp < 0) {	# change this when copying
		$level = $a{max};
		$o->signal($a{signal}, $a{sample}, $date);
	    } elsif ($prev_comp < 0 and $comp >= 0) {	# change this when copying
		$level = $a{min} ;
	    } else {
		$level = condition_level( $level, \%a );
	    }
	}
	$level = $a{max} if $level > $a{max};
	$level = $a{min} if $level < $a{min};
	$prev_comp  = $comp;
	$res{$date} = $level;
    }

    return %res ? \%res : undef;
}

sub test_ge {
    my ($o, $data, %a) = @_;					# See test for list of keys

    my $prev_comp;
    my $level = 0;
    my %res;
    foreach my $date (sort keys %$data) {
	my $comp = $data->{$date};
	if (defined $prev_comp and defined $comp) {
	    if ($prev_comp < 0 and $comp >= 0) {	# change this when copying
		$level = $a{max};
		$o->signal($a{signal}, $a{sample}, $date);
	    } elsif ($prev_comp >= 0 and $comp < 0) {	# change this when copying
		$level = $a{min} ;
	    } else {
		$level = condition_level( $level, \%a );
	    }
	}
	$level = $a{max} if $level > $a{max};
	$level = $a{min} if $level < $a{min};
	$prev_comp  = $comp;
	$res{$date} = $level;
    }

    return %res ? \%res : undef;
}

sub test_le {
    my ($o, $data, %a) = @_;					# See test for list of keys

    my $prev_comp;
    my $level = 0;
    my %res;
    foreach my $date (sort keys %$data) {
	my $comp = $data->{$date};
	if (defined $prev_comp and defined $comp) {
	    if ($prev_comp > 0 and $comp <= 0) {	# change this when copying
		$level = $a{max};
		$o->signal($a{signal}, $a{sample}, $date);
	    } elsif ($prev_comp <= 0 and $comp > 0) {	# change this when copying
		$level = $a{min} ;
	    } else {
		$level = condition_level( $level, \%a );
	    }
	}
	$level = $a{max} if $level > $a{max};
	$level = $a{min} if $level < $a{min};
	$prev_comp  = $comp;
	$res{$date} = $level;
    }

    return %res ? \%res : undef;
}

sub test_eq {
    my ($o, $data, %a) = @_;					# See test for list of keys

    my $prev_comp;
    my $level = 0;
    my %res;
    foreach my $date (sort keys %$data) {
	my $comp = $data->{$date};
	if (defined $prev_comp and defined $comp) {
	    if ($prev_comp != 0 and $comp == 0) {	# change this when copying
		$level = $a{max};
		$o->signal($a{signal}, $a{sample}, $date);
	    } elsif ($prev_comp == 0 and $comp != 0) {	# change this when copying
		$level = $a{min} ;
	    } else {
		$level = condition_level( $level, \%a );
	    }
	}
	$level = $a{max} if $level > $a{max};
	$level = $a{min} if $level < $a{min};
	$prev_comp  = $comp;
	$res{$date} = $level;
    }

    return %res ? \%res : undef;
}

sub test_ne {
    my ($o, $data, %a) = @_;					# See test for list of keys

    my $prev_comp;
    my $level = 0;
    my %res;
    foreach my $date (sort keys %$data) {
	my $comp = $data->{$date};
	if (defined $prev_comp and defined $comp) {
	    if ($prev_comp == 0 and $comp != 0) {	# change this when copying
		$level = $a{max};
		$o->signal($a{signal}, $a{sample}, $date);
	    } elsif ($prev_comp != 0 and $comp == 0) {	# change this when copying
		$level = $a{min} ;
	    } else {
		$level = condition_level( $level, \%a );
	    }
	}
	$level = $a{max} if $level > $a{max};
	$level = $a{min} if $level < $a{min};
	$prev_comp  = $comp;
	$res{$date} = $level;
    }

    return %res ? \%res : undef;
}

### SUPPORT FUNCTIONS

sub ensure_common_values {
    my ($base1, $base2) = @_;
    my $data1 = $base1->{data} || {};
    my $data2 = $base2->{data} || {};
    my %temp = (%$data1, %$data2);
    foreach my $date (keys %temp) {
	my $v1 = $data1->{$date};
	my $v2 = $data2->{$date};
	if (defined $v1 and defined $v2) {
	    $temp{$date} = ($v1 <=> $v2);
	} else {
	    delete $temp{$date};
	}
    }
    return \%temp;
}
# returns hash containing only values common to both lines

sub condition_level {
    my ($level, $h) = @_;

    my $lvl = $level - $h->{min};
    $lvl = $lvl*$h->{decay} + $h->{ramp};
    return $lvl + $h->{min};
}


=head1 BUGS

Please report those you find to the author.

=head1 AUTHOR

Chris Willmot, chris@willmot.org.uk

=head1 SEE ALSO

L<Finance::Shares::Sample>,
L<Finance::Shares::Chart>.

There is also an introduction, L<Finance::Shares::Overview> and a tutorial beginning with
L<Finance::Shares::Lesson1>.

=cut

1;

