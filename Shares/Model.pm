package Finance::Shares::Model;
our $VERSION = 0.15;
use strict;
use warnings;
use Carp;
use PostScript::File	     1.00;
use Finance::Shares::Sample  0.12 qw(line_id call_function %function);
use Finance::Shares::Chart   0.14 qw(deep_copy);

#use TestFuncs qw(show show_deep show_lines);

our %testfunc;
$testfunc{gt} = \&test_gt;
$testfunc{lt} = \&test_lt;
$testfunc{ge} = \&test_ge;
$testfunc{le} = \&test_le;
$testfunc{eq} = \&test_eq;
$testfunc{ne} = \&test_ne;
$testfunc{min} = \&test_min;
$testfunc{max} = \&test_max;
$testfunc{diff} = \&test_diff;
$testfunc{sum} = \&test_sum;
$testfunc{and} = \&test_and;
$testfunc{or} = \&test_or;
$testfunc{not} = \&test_not;
$testfunc{test} = \&test_test;

our %testpre;
$testpre{min} = 'lowest of';
$testpre{max} = 'highest of';
$testpre{not} = 'not';
$testpre{test} = 'test';

our %testname;
$testname{gt} = 'above';
$testname{lt} = 'below';
$testname{ge} = 'above or touching';
$testname{le} = 'below or touching';
$testname{eq} = 'same as';
$testname{ne} = 'different from';
$testname{min} = 'and';
$testname{max} = 'and';
$testname{diff} = 'minus';
$testname{sum} = 'plus';
$testname{and} = 'and';
$testname{or} = 'or';

our %sigfunc;
$sigfunc{mark}         = \&signal_mark;
$sigfunc{mark_buy}     = \&signal_mark_buy;
$sigfunc{mark_sell}    = \&signal_mark_sell;
$sigfunc{print}        = \&signal_print;
$sigfunc{print_values} = \&signal_print_values;
$sigfunc{custom}       = \&signal_custom;

our $points_margin = 0.02;	# logical 0/1 is mark_range -/+ points_margin * mark_range

=head1 NAME

Finance::Shares::Model - Apply tests to stock quotes

=head1 SYNOPSIS

    use Finance::Shares::Model;

Two ways to use this module.  Either all the data can be given to the constructor, with the model run
immediately, or tests can be administered piece by piece in a script.

These two approaches are illustrated here.  Both draw circles around the volume where a day's highest price is
more than 3% above the previous closing price.

=head2 Packaged model

    use Finance::Shares::Model;
    use Finance::Shares::Bands;

    my $fsm = new Finance::Shares::Model(
	sources => [
	    db => {
		# Finance::Shares::MySQL options
	    },
	],
    
	charts => [
	    main => {
		# Finance::Shares::Chart options
	    },
	],

	files => [
	    myfile => {
		# PostScript::File options
	    },
	],

	functions => [
	    env => {
		function => 'envelope',
		percent  => 3,
	    },
	],

	tests => [
	    good_vol => {
		graph1 => 'prices', line1 => 'env_high',
		graph2 => 'prices', line2 => 'high',
		test   => 'ge',
		graph  => 'tests',
		signal => [ 'highlight_volume' ],
	    },
	],

	signals => [
	    highlight_volume => [ 'mark', {
		graph => 'volumes',
		line  => 'volume',
		key   => 'price above envelope',
		style => {
		    point => {
			color => [1, 0, 0],
			shape => 'circle',
			size  => 15,
		    },
		},
	    }],
	],

	groups => [
	    main => {
		source    => 'db',
		functions => ['env'],
		tests     => ['good_vol'],
		chart     => 'main',
		file      => 'myfile',
	    },
	],

	samples => [
	    stock1 => {
		# Finance::Shares::Sample options
	    },
	],
    );
    
    $fsm->output();
    
=head2 Low level control

    use Finance::Shares::Model;
    use Finance::Shares::MySQL;
    use PostScript::File;
    use Finance::Shares::Sample;
    use Finance::Shares::Chart;

    use Finance::Shares::Bands;
    
    my $sql = new Finance::Shares::MySQL(...);
    my $psf = new PostScript::File(...);
    my $fss = new Finance::Shares::Sample(
	source     => $sql,
	file       => $psf,
	...
    );
    
    my $fsm = new Finance::Shares::Model;
    $fsm->add_sample( $fss );
    $fsm->add_signal('highlight_volume', 'mark', undef, {
	graph => 'volumes',
	line  => 'volume',
	key   => 'price above envelope',
	style => {
	    point => {
		color => [1, 0, 0],
		shape => 'circle',
		size  => 15,
	    },
	},
    });

    my ($high, $low) = $fss->envelope( percent => 3 );
    $fsm->test(
	graph1 => 'prices', line1 => $high,
	graph2 => 'prices', line2 => 'high',
	test   => 'ge',
	graph  => 'tests',
	signal => [ 'highlight_volume' ],
    );

    my $fsc = new Finance::Shares::Chart(
	sample => $fss,
	...
    );
    $fsc->output('myfile');       
	
=head1 DESCRIPTION

This module provides the testing enviroment for the Finance::Shares suite.  A model brings a group of
L<Finance::Shares::Samples> together and applies tests to them all.  The tests usually rely on functions from other
modules such as L<Finance::Shares::Averages>, and the results are displayed on a L<Finance::Shares::Chart>.

Either the Finance::Shares::Model constructor is passed no options or it is passed details of the whole model.
The latter format is covered under the L<CONSTRUCTOR> options.

If the constructor has no options, nothing will happen until B<add_sample> has been called at least once (and
B<add_signals> if signals are used in the tests).  Tests are applied to all samples, which don't need to
have anything in common with each other.  However, if the date ranges are completely different it would probably
be better to run seperate models.  This is because the Model's date range covered by each of the tests is
made from all dates in all samples.

=head2 The tests

The tests currently available are:

    gt	    1st line moves above 2nd
    lt	    1st moves below 2nd
    ge	    1st moves above or touches 2nd
    le	    1st moves below or touches 2nd
    eq	    1st touches 2nd
    ne	    1st doesn't touch 2nd
    min	    Smallest of 1st and 2nd
    max	    Largest of 1st and 2nd
    sum	    1st + 2nd
    diff    1st - 2nd
    and	    Logical 1st AND 2nd
    or	    Logical 1st OR 2nd
    not	    Logical NOT 1st
    test    Logical value of 1st

Tests produce data lines in the standard format.  This means that data, functions and tests can be used
interchangeably.  Tests can all be shown on any graph (or hidden).  Wherever a 'line' is expected, it can be
a data, function or test line.  I think a circular reference is not possible because of the declaration order, but
it would be a Very Bad Thing (TM) so be aware of the possibility.

B<not> and B<test> are unary, only working on the first line given.  The line values are converted to digital
form, taking one of two values.  On the tests graph, these are 0 and the weight given to the test (up to 100).
Other graphs have suitable minimum and maximum values depending on the Y axis scale.

B<test> might be considered as B<not(not(...))>.  It uses a C<divide> value to convert the source line to 'on' or
'off'.  This can be further conditioned by having this value decay over time.  Another use of B<test> is to
trigger signals on pseudo-test functions like C<rising> or C<undersold>.

All the logical tests (and, or, not and test) can be performed for their signals only if the C<noline> option is
set.

=head2 The signals

The results lines are analog in that they can take a range of values.  Indeed they can be made to decrease over
time.  But at any particular time they have a level or B<state>.  Signals, on the other hand, are a form of
output that is inherently digital - either it has been invoked or it hasn't.  All tests can have zero or more
signals associated with them which are invoked when some critical B<change> of state happens, like when one line
crosses over another.  Currently the following signals are available:

    mark	    Places a mark on a graph
    mark_buy	    Draws a blue up arrow
    mark_sell	    Draws a red down arrow
    print_values    Write function/test values to a file
    print	    Print a message on the console
    custom	    Invoke a user defined callback


=head1 CONSTRUCTOR

A model can be specified completely in the option hash given to B<new()>, so the whole process is very simple:

    my $fsm = new Finance::Shares::Model(
	    # model specified here
	);
    $fsm->output();

The specification consists of eight resources: sources, files, charts, functions, tests, signals, groups and
samples.  If the name is plural, it should refer to an array holding several named hashes each describing one of
them.

Example 1

    functions => [
	slow => {...},
	g    => {...},
	vol5 => {...},
    ],

B<new()> will accept either a list of key/value pairs or a hash ref containing them, so each specification would
normally be terminated by a comma.

The key/value pairs are a named group of settings, typically used to constuct an object.  The name can be used
anywhere else in the model specification; whenever that object needs referred to.

Example 2

    files => [
	stock1 => { ... },
	stock2 => { ... },
    ],

    charts => [
	chart1 => {
	    file => 'stock2',
	    ...
	}
    ],

In an array, the first entry is treated as the default and is used where that resource is not specified.
Alternatively, the resource can be singular, in which case those are the default settings used throughout and
given the name 'default'.

Example 3

    file => {
	paper => 'A4',
	landscape => 1,
    },

Here, the file takes on the name 'default', so would be saved as F<default.ps>.
    
Notice that the singular resource name must refer to a hash.  There is no singular item 'signal' as individual
signals are specified as arrays and not hashes.

=head2 Sources

A C<source> entry is anything that can be passed to the Finance::Shares::Sample option of the same name.  So this
could be one of the following.

=over 8

=item array

The array ref should point to quotes data held in sub-arrays.

=item string

This should be the name of a CSV file holding quotes data.

=item hash

A hash ref holding options for creating a new Finance::Shares::MySQL object.

=item object

A Finance::Shares::MySQL object created elsewhere.

=back

There must be at least one source, and the hash ref is probably the most useful.  See L<Finance::Shares::MySQL>
for full details, but the top level keys that can be used here include:

    hostname	    port
    user	    password
    database	    exchange
    start_date	    end_date
    mode	    tries

Example 4

    sources => [
	database => {
	    user     => 'me',
	    password => 'Gu355',
	    database => 'mystocks',
	},
	test => 'test_file.csv',
    ],

=head2 Files

Each hash ref holds options for creating a PostScript::File object.  It will be created once and any charts using
it will be added on a new page.

If the C<files> (plural) resource has been declared, it contains one or more named hash refs.  These key names become
the name of the file, with '.ps' appended.  Any chart resource using this name as it's C<file> entry specifies
(one of) the layout(s) that will appear there.  Each sample using that chart specification is therefore put in
that chart's file.

See L<PostScript::File> for full details but these are the more useful sub-hash keys:

    paper	    eps
    height	    width
    bottom	    top
    left	    right
    clip_command    clipping
    dir		    file
    landscape	    headings
    reencode

Example 5
    
    files => [
	retail => { ... },
    ],

    samples => [
	sample1 => {
	    symbol => 'TSCO.L',
	    file   => 'retail',
	    ...
	},
    ],

Here the Tesco sample will appear as a page in the file F<retail.ps>.

On the other hand, the specification may be held in a C<file> (singular) hash.  In this case the sample
specification holds no C<file> entry, so every chart will appear in the default file.  Where the
C<files> (plural) resource is used, the default will be the first entry in the array (unless another entry has
the key name 'default', when it is used instead).  

The way to put all samples' charts into the same file is to have only one file, as in the example above (under
'named').  Each sample's chart will find its way there either because it was specified or because it is the
default (and it happens to have a name).

Where the default has been declared as a C<file> (singular) resource hash, it has no explicit name, so will be
stored in a file called F<default.ps>.

=head2 Charts

These are Finance::Shares::Chart options.  It is probably a good idea to pre-define repeated elements (e.g.
colours, styles) and use the perl variables as values in the hash or sub-hashes.  See L<Finance::Shares::Chart>
for full details, but these top level sub-hash keys may be used in a chart resource:

    prices	    volumes
    cycles	    tests
    x_axis	    key
    dots_per_inch   reverse
    bgnd_outline    background
    heading_font    normal_font
    heading

Each graph sub-hash may contain the following keys, as well as 'points' for prices and 'bars' for volumes.

    percent	    show_dates
    layout	    y_axis
    
When the model is run, three keys are filled internally and should NOT be specified here:

=over 8

=item sample

The Finance::Shares::Sample object created from the B<samples> resource is assigned to this.

=item file

This is specified in the B<samples> resource.  Where this is not named explicitly, the default name is assumed.
The name should be a key from the B<files> resource.  The corresponding PostScript::File object will be assigned
in its place.

=item page

The B<samples> hashes may have a field, 'page' which is assigned here.

=back

=head2 Functions

This array ref lists all the functions known to the model.  Like the other resources, they may or may not be used.
However, unlike the others, the sub-hashes are not all the same format.  The only requirement is that they have an
additional key, C<function> which holds the name of the method.  However, these keys are common:

    graph	    line
    period	    percent
    strict	    shown
    style	    key

Example 6

    functions => {
	grad1	 => {
	    function => 'gradient',
	    period   => 1,
	    style    => $fn_style,
	},
	grad_env => {
	    function => 'envelope',
	    percent  => 5,
	    graph    => 'cycles',
	    line     => 'grad1',
	    style    => $fn_style,
	},
	expo     => {
	    function => 'exponential_average',
	},
    },

Here C<grad1> is constructed from the L<Finance::Shares::Momentum> method, B<gradient> which uses closing prices
by default and puts its results on the cycles graph.  The L<Finance::Shares::Bands> method B<envelope> uses this
to add lines 5% above and below the grad1 line.  Another function C<expo> uses all default values when evaluating
the B<exponential_average> method from L<Finance::Shares::Averages>.  C<$fn_style> would probably be a hash ref
holding L<PostScript::Graph::Style> options.

If the C<function> (singular) version is used, the function defined there takes on the name 'default'.

=head2 Tests

See L</test> for details of the keys allowed in these named sub-hashes:

    graph1	    line1
    graph2	    line2
    test	    signals
    shown	    style
    graph	    key
    decay	    ramp
    weight

Example 7

    tests => [
	high_vol => {
	    graph1 => 'volumes',
	    line1  => 'v250000',
	    test   => 'ge',
	    signal => ['good_vol', 'record'],
	    graph2 => 'volumes',
	    line2  => 'volume',
	    key    => 'high volume',
	},
    ],

    functions => [
	v250000 => {
	    function => 'value',
	    graph    => 'volumes',
	    value    => 250000,
	    shown    => 0,
	},
	...
    ],
    
This will produce a line on the tests graph in the default style.  The software generates keys describing each
line, but they can get very long.  It is often best to declare your own.  See Example 8 for the signal
definitions.

The function C<v250000> uses the B<value> method from L<Finance::Shares::Sample> and is not visible because the
signal 'good_vol' will show where it is relevent.  There would be no problem giving the same name to different
resources, but calling the signal 'good_vol' and the test 'high_vol' makes the example clearer.

If the C<test> (singular) version is used, the test defined there takes on the name 'default'.

=head2 Signals

Only the plural C<signals> version is available.  The named entries are array refs and not hash refs like all the
others.  They list the parameters for the B<add_signal> method.  See L</add_signal>.

Example 8

    signals => [
	good_vol => [ 'mark', undef, { 
	    graph   => 'volumes',
	    line    => 'volume',
	    key     => 'volume over 250000',
	}],
	record   => [ 'print_values', {
	    message => '$date: vv between hh and ll',
	    lines   => {
		vv	=> 'volumes::volume',
		hh	=> 'prices::highest price',
		ll	=> 'prices::lowest price',
	    },
	    masks   => {
		vv	=> '%d',
		hh	=> '%7.2f',
		ll	=> '%7.2f',
	    },
	}],
    ],

The C<good_vol> signal rings all volumes above 250000 and C<record> prints out the volume and price range for that
day.  It is even more important to provide a key to 'mark' type signals.  Using the default keys quickly leads to half the
page being taken up with the Key panels.
    
Like functions, the specifications vary according to the type of signal used - the first entry in the array ref.
The second entry may be omitted if it would be C<undef>.  The third is often a hash ref passed to the signal
handler, although this may be different for custom signals.  See L</print_values> for an explanation of the
C<record> signal entries.

=head2 Samples

A model may run tests and evaluate functions for several samples.  This is where the individual samples are
specified, and there must be at least one.  The order is significant in that it affects how the charts are added
to the file(s).  The sub-hash entries include options for creating a L<Finance::Shares::Sample> object:

    start_date	    end_date
    symbol	    dates_by
    mode

There are, however, some significant additions.

=over 8

=item source

This should be the name of the sources resource to use.  That value then becomes the C<source> entry for the
Finance::Shares::Sample constructor.

=item file

The name of the B<files> resource specifying where the chart will go.

=item chart

One chart is created per sample, and this should be the name of the B<charts> resource holding the
Finance::Shares::Chart constructor options to use.

=item page

As mentioned under L</Charts>, it is possible to specify a page identifier for every chart here.  Bear in mind,
though, that this becomes the PostScript page 'number' and as such should be short and have no embedded spaces.
The stock symbol is ideal.

=item functions

(Note the plural.)  This should be an array ref holding the names of all the function lines to be evaluated for
the sample.  There is no 'default' - omitting this key means no functions are evaluated.  The functions will be
evaluated in the order they appear.

=item tests

(Note the plural.)  This should be an array ref holding the names of all the tests to be performed on the sample.
There is no 'default' - omitting this key means no tests are done.  They will be evaluated in the order they
appear.

=item groups

(Note the plural.) If present, this should be an array ref holding names of zero or more B<groups> of settings.
The settings are added in the order the group names are given, so later groups can override earlier settings.
These can always be overridden by specifying the key directly.  Notice that subsequent keys override previous
ones, so if two groups both have lists of functions only the second list will be used.

If no 'groups' entry is present, the default group is assumed.  To prevent this, set to '[]'.

=back

Although it is possible to specify different dates for each sample, this should be used with care.  The date range
includes every date needed for every sample and an attempt is made to calculate functions and tests for them all.
If there is no reason for the overlap it would be better to run seperate models only differing by stock symbol and
price.

As with other resources, C<sample> (singlular) may be used if only one is required.

Example 9

    samples => [
	1 => { symbol => MSFT, dates_by => 'weekdays', },
	2 => { symbol => MSFT, dates_by => 'weeks', },
	3 => { symbol => HPQ,  dates_by => 'weekdays', },
    ],

Note that the sample names are ignored.

It is possible to use C<sample> (singular) to specify just one sample.

Example 10

    sample => {
	symbol     => 'BSY.L',
	start_date => '2002-10-01',
	end_date   => '2002-12-31',
	dates_by   => 'days',
	functions  => [ 'simple3', 'expo20' ],
	tests      => [ 'simple_above_expo' ],
    },

The default source, file and chart entries are assumed.

=head2 Groups

To avoid repetition it is possible to name a collection of B<samples> settings which are used together.  If
a groups (or group) resource exists, the default group will be used in every sample that doesn't have a 'group'
entry.

Example 11

    groups [
	basic => {
	    file       => 'file1',
	    chart      => 'price_only',
	    start_date => '2002-01-01',
	    end_date   => '2002-12-31',
	    dates_by   => 'weeks',
	},
	gradient => {
	    chart      => 'inc_cycles',
	    functions  => [qw(simple3 grad1 chan10)],
	},
	vol_tests => {
	    chart      => 'inc_signals',
	    functions  => [qw(v250000 expo5 expo20)],
	    tests      => [qw(high_vol move_up and)],
	},
    ],

    samples [
	1 => {
	    symbol   => 'BSY.L',
	    page     => 'BSY',
	},
	2 => {
	    symbol   => 'BSY.L',
	    page     => 'BSYm',
	    dates_by => 'months',
	    groups   => [qw(basic gradient)],
	},
	3 => {
	    symbol   => 'PSON.L',
	    file     => 'file2',
	    groups   => ['vol_tests'],
	},
    ],

Assume the named references are all defined in their appropriate resource arrays.  Both BSkyB samples
will appear on F<file1.ps>, but only the 'months' chart will have any lines on it.  The Pearson sample will use
the same dates but the chart using the 'inc_signals' specification will be written to F<file2.ps>.

=cut

sub new {
    my $class = shift;
    my $opt = {};
    if (@_ == 1) { $opt = $_[0]; } else { %$opt = @_; }
  
    ## Initialization
    my $o = {
	opt       => $opt,
	
	fsc       => {},    # Finance::Shares::Chart objects as {filename}[]
	psf       => {},    # PostScript::File objects indexed by filename
	fss       => {},    # Finance::Shares::Sample objects (from add_samples)
	order     => [],    # sequence of {samples} keys (from add_samples)
	sigfns    => {},    # from add_signals
	lines     => {},    # function/test id => sample line id, for each sample only
	
	run       => 0,	    # true if run() has created charts
	start     => '9999-99-99',
	end       => '0000-00-00',
    };
    bless( $o, $class );

    $o->{cgi_file} = $opt->{cgi_file} || 'STDOUT';
    $o->{verbose}  = defined($opt->{verbose})  ? $opt->{verbose}  : 1;  
    $o->{dir}      = $opt->{directory};
    $o->{delay}    = %$opt ? 0 : 1;
    $o->{delay}    = ($opt->{run} == 0) if defined $opt->{run};
    
    ## Resources
    $o->resource('source');
    $o->resource('file');
    $o->resource('chart');
    $o->resource('function');
    $o->resource('test');
    $o->resource('signal');
    $o->resource('group');
    $o->resource('sample');
    
    ## PostScript::File objects
    my $of = $o->{files};
    die "No PostScript files\n" unless ($of and ref($of) eq 'HASH');
    while( my ($id, $h) = each %$of ) {
	$o->ensure_psfile( $id, $h );
    }
   
    my $os = $o->{signals};
    if (ref($os) eq 'HASH') {
	while( my ($id, $ar) = each %$os ) {
	    next unless ref($ar) eq 'ARRAY';
	    my ($type, $obj, $hash) = @$ar;
	    if (ref($obj) eq 'HASH') {
		$hash = $obj;
		$obj  = undef;
	    }
	    $o->add_signal($id, $type, $obj, $hash);
	}
    }

    $o->run() unless $o->{delay};
    return $o;
}

=head2 new( [ options ] )

C<options> can be a hash ref or a list of hash keys and values.  Most of the top level keys are outlined above.
However, there are a few general ones controlling how this module behaves.

=over 4

=item cgi_file

Specify the name of the C<file> or C<files> hash to be printed to STDOUT rather than to a file with that name.
(Default: 'STDOUT')

=item directory

If the file names are not absolute paths, they will be placed in this directory.  (Default: undef)

=item run

Setting this to 0 prevents the constructor from running the model.  A model is assumed if there are ANY
parameters: if no parameters are given, this defaults to 0, otherwise the default is 1.

=item verbose

Gives some control over the number of messages sent to STDERR during the process.

    0	Only fatal messages
    1	Minimal
    2	Report each process
    3+	Debugging

=back

=head1 MAIN METHODS

=cut

sub run {
    my $o = shift;
    
    foreach my $id (@{$o->{sampleord}}) {
	my $h0 = $o->{samples}{$id};
	die "Missing sample hash\n" unless ref($h0) eq 'HASH';
	$o->out(2, "Sample for $h0->{symbol}:") if $h0->{symbol};
	
	## sample hash
	my $gname = $h0->{group} || $o->{defgroup};
	my $group = $o->{groups}{$gname} if $gname;
	my @args = %$group if ref($group) eq 'HASH';
	if (ref($h0->{groups}) eq 'ARRAY') {
	    foreach my $gname (@{$h0->{groups}}) {
		my $group = $o->{groups}{$gname};
		push @args, %$group if ref($group) eq 'HASH';
	    }
	}
	my $sname = $h0->{source} || $o->{defsource};
	push @args, %$h0, (source => $o->{sources}{$sname});
	my $h = deep_copy( { @args } );
	#print "Model::run sample=$id\n", show_hash($h);
	
	$h->{source}{verbose} = $o->{verbose} if ref $h->{source} eq 'HASH';
	my $fss;
	eval {    
	    $fss = new Finance::Shares::Sample( $h );
	};
	if ($@) {
	    $o->out(0, "    Error with sample: $@");
	    next;
	}
	$o->add_sample( $fss );

	## chart
	my $filename = $h->{file} || $o->{deffile};
	my $psf = $o->{psf}{$filename}; 
	die "No PostScript::File object named '$filename'\n" unless $psf;
	@args = (
	    sample => $fss,
	    file   => $psf,
	    page   => $h->{page},
	);
	my $cname = $h->{chart} || $o->{defchart} || '';
	my $chash = $o->{charts}{$cname}; 
	my @chart = %{deep_copy($chash)} if ref($chash) eq 'HASH'; 
	$o->{fsc}{$filename} = [] unless defined $o->{fsc}{$filename};	    # charts for that file
	push @{$o->{fsc}{$filename}}, new Finance::Shares::Chart(@chart, @args);
	$o->out(2, "    ". "Using chart '$cname' for " .
	    ($filename eq 'STDOUT' ? 'STDOUT' : "file '$filename.ps'"));

	## functions
	my %lines;
	if (ref($h->{functions}) eq 'ARRAY') {
	    foreach my $id (@{$h->{functions}}) {
		my $h0 = $o->{functions}{$id};
		my $fh = deep_copy($h0);
		my $fname = $fh->{function};
		next unless $fname;
		patch_line(\%lines, $fh, 'line');
		my ($line1, $line2) = call_function( \%function,$fname, $fss,%$fh );
		if (defined $line2) {
		    $lines{$id . '_high'} = $line1;
		    $lines{$id . '_low'} = $line2;
		    $o->out(4, '    ' . $id . "_high = function $line1");
		    $o->out(4, '    ' . $id . "_low  = function $line2");
		} else {
		    $lines{$id} = $line1;
		    $o->out(4, '    ' . "$id = function $line1");
		}
	    }
	}

	## tests
	if (ref($h->{tests}) eq 'ARRAY') {
	    foreach my $id (@{$h->{tests}}) {
		my $h0 = $o->{tests}{$id};
		my $th = deep_copy($h0);
		patch_line(\%lines, $th, 'line1');
		patch_line(\%lines, $th, 'line2');
		$o->patch_signals(\%lines, $th->{signals});
		my $line_id = $o->test_sample($fss, $th);
		$lines{$id} = $line_id;
		$o->out(3, '    ' . "$id = test $line_id");
	    }
	}
	#print show_lines($fss);
	#print show_hash(\%lines);
	$o->out(1, "Finished sample '". $fss->id() ."'");
    }

    $o->{run} = 1;
}

sub add_sample {
    my ($o, $s) = @_;
    die unless $s->isa('Finance::Shares::Sample');
    my $start = $s->start_date();
    my $end   = $s->end_date();
    my $id    = $s->id();
    push @{$o->{order}}, $id;
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
    my ($o, $id, $signal, $obj, @args) = @_;
    if ($sigfunc{$signal}) {
	die "There is already a signal registered as '$id'\n" if defined $o->{sigfns}{$id};
	$o->{sigfns}{$id} = [ $signal, $obj, @args ];
    } else {
	die "Unknown signal function type '$signal'\n";
    }
}

=head2 add_signal( id, signal, [ object [, args ]] )

Register a callback function which will be invoked when some test evaluates 'true'.

=over 8

=item id

A string identifying the signal.  This must be unique.

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
    my $opt = {};
    if (@_ == 1) { $opt = $_[0]; } else { %$opt = @_; }
    my $h = {
	graph1	=> 'prices',	line1	=> 'close',
	#graph2	=> 'prices',	#line2	=> 'close',	# only defined when not unary test
	test	=> 'gt',	shown	=> 1,		style	=> {},
	weight	=> 100,		decay	=> 1,		ramp	=> 0,
	%$opt,
    };

    my $id;
    foreach my $s (values %{$o->{samples}}) {
	$id = $o->test_sample($s, $h);
    }
 
    return $id;
}

=head2 test( options )

A test is added to the model and the resulting line added to each Sample.  Signals are invoked when a date is
encountered that passes the test.  Tests may be binary (working on two lines) or unary (just working on one).

The method returns the identifier string for the resulting data line.

C<options> may be either a list or a hash ref.  Either way it should contain parameters passed as key => value
pairs, with the following as known keys.

=over 8

=item graph1

The graph holding C<line1>.  Must be one of 'prices', 'volumes', 'cycles' or 'tests'.

=item line1

A string identifying the only line for a unary test or the first line for a binary test.

=item graph2

The graph holding C<line2>.  Must be one of 'prices', 'volumes', 'cycles' or 'tests'.  Defaults to C<graph1>.

=item line2

A string identifying the second line for a binary test.  For a unary test this must be undefined.

=item test

The name of the test to be applied, e.g 'gt' or 'lt'.  Note this is a string and not a function reference.

=item noline

[Only logical tests B<and>, B<or>, B<not> and B<test>.]  When '1', the results line is not generated.  Only useful
when signals are triggered and the line is not needed for other tests.  (Default: 0)


=item shown

True if the results should be shown on a graph.

=item style

If present, this should be either a PostScript::Graph::File object or a hash ref holding options for creating one.

=item graph

The destination graph, where C<line> will be displayed.  Must be one of 'prices', 'volumes', 'cycles' or 'tests'.

If not specified, C<graph1> is used.  This is a little odd as the scales are usually meaningless.  However, as
mostly the result is an on-or-off function, the line is suitably scaled so the shape is clear enough.

=item key

The string which will appear in the Key panel identifying the test results.

=item divide

[Only for B<not> and B<test> tests.]  This sets the point dividing 'true' from 'false' and should be a value
within the range of C<line1> values.  (Default: 0)

=item weight

How important the test should appear.  Most tests implement this as the height of the results line.

=item decay

If the condition is met over a continuous period, the results line can be made to decay.  This factor is
multiplied by the previous line value, so 0.95 would produce a slow decay while 0 signals only the first date in
the period.

=item ramp

An alternative method for conditioning the test line.  This amount is added to the test value with each
period.

=item signals

This should be an array ref holding one or more of the signals registered with this model.

=back

The results line would typically be shown on the 'tests' graph.  Most tests are either true or false, so the
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
    
    my ($psf, $filename, $dir);
    unless ($o->{run}) {
	$psf = shift;
	my $ref = ref $psf;
	if ($psf and ($ref eq 'HASH' or $ref eq 'PostScript::File')) {
	    ($filename, $dir) = @_;
	} else {
	    $dir = shift;
	    $filename = $psf;
	    $psf = undef;
	}
	$o->ensure_psfile( $filename, $psf );
	$o->run();
    }
    $dir = $o->{dir} unless defined $dir;

    my $res = '';
    while( ($filename, $psf) = each %{$o->{psf}} ) {
	die "There is no PostScript::File for '$filename'\n" unless ref($psf) eq 'PostScript::File';
	my $pages = 0;
	my $sample;
	foreach my $fsc (@{$o->{fsc}{$filename}}) {
	    $psf->newpage() if $pages++;
	    $o->out(3, "Building chart '" . $fsc->title() . "'");
	    $fsc->build_chart($psf);
	    $sample = $fsc->sample()->id();
	}
	if ($pages) {
	    if ($filename eq $o->{cgi_file}) {
		$o->out(2, "Written to STDOUT");
		$res = $psf->output();
	    } else {
		if ($sample and $filename =~ /^file\d*$/) {
		    my ($symbol, $start, $days, $end) = $sample =~ /([^\(]+)\(([^,]+),([^,]+),([^\)]+)/;
		    $filename = "${symbol}_${days}_${start}_to_${end}";
		}
		$o->out(2, "Saving '". ($dir ? "$dir/" : '') . "$filename.ps'");
		$psf->output($filename, $dir);
	    }
	}
    }

    return $res;
}


=head2 output( [psfile,] [filename [, directory]] )

C<psfile> can either be a L<PostScript::File> object, a hash ref suitable for constructing one or undefined.

The charts are constructed and written out to the PostScript file.  A suitable suffix (.ps, .epsi or .epsf) will
be appended to C<filename>.

If no filename is given, the PostScript text is returned.  This can then be piped to B<gs> for conversion into
other formats, or output directly from a cgi script.

Example 1

    my $file = $fsm->output();

The PostScript is returned as a string.  The PostScript::File object has been constructed using defaults which
produce a landscape A4 page.

Example 2

    $fsm->output('myfile');

The default A4 landscape page(s) is/are saved as F<myfile.ps>.

Example 3

    my $pf = new PostScript::File(...);
    my $file = $fsm->output($pf);

The pages are formatted according to the PostScript::File parameters.  The same result would have been obtained
had $pf been a hash ref.

Example 4

    my $pf = new PostScript::File(...);
    $fsm->output($pf, 'shares/myfile', $dir);

The specially tailored page(s) is/are written to F<$dir/shares/myfile.ps>.

Note that it is not possible to print the charts individually once B<output()> has been called.  However, it is
possible to output them seperately to their own files, I<then> call this to output a file showing them all.

=cut

=head1 SIGNALS

Before they can be used signals must have been registered with the Model using B<add_signal>.
The name must then be given to B<test> as (part of) the B<signal> value.

Most parameters are given when it is registered, but the date and Y value of the signal is also passed to the handler.

=cut

sub signal_mark {
    my ($s, $id, $date, $value, $p) = @_;
    die "Cannot mark buy signal: no date\n" unless defined $date;
    $p->{key} = $id unless defined $p->{key};
    $p->{shown} = 1 unless defined $p->{shown};

    $p->{style} = {
	point => {
	    shape => 'circle',
	    size  => 10,
	    color => [0.5, 0.7, 0.0],
	},
    } unless defined $p->{style};
    
    if (defined $p->{value}) {
	$value = $p->{value};
    } elsif (defined $p->{line}) {
	$p->{graph} = 'prices', $p->{line} = 'close' unless defined $p->{graph};
	my $vline = $s->choose_line($p->{graph}, $p->{line});
	die "Cannot mark buy signal: line '$p->{line}' does not exist on $p->{graph}\n" unless defined $vline;
	$value = $vline->{data}{$date};
    }
    die "Cannot mark buy signal: no value\n" unless defined $value;
    
    # changes here must be reflected in test() patch
    my $graph = $p->{graph} || 'tests';
    my $line_id = "signal($id)";
    my $buy = $s->choose_line( $graph, $line_id, 1 );
    $buy = $s->add_line( $graph, $line_id, {}, $p->{key}, $p->{style}, $p->{shown} ) unless defined $buy;
    $buy->{data}{$date} = $value;
}

=head2 mark

A point is drawn on a graph when the test evaluates 'true'.  The following parameters may be passed to
B<add_signal> within a hash ref.

Example

    $fsm->add_signal('note_price', 'mark', undef, {
	graph => 'prices', 
	line  => 'high',
    });
    
=over 8

=item graph

One of prices, volumes, cycles or tests.  If you have specified a particular graph for the test, you probably
want to set this to the same.

=item value

If present, this should be a suitable Y coordinate.  No bounds checking is done.

=item line

The Y coordinate may be obtained from the line identified by this string.  By default, the test line value is
used.  C<graph> should be set if this is given.

=item key

Optional string appearing in the Key panel.

=item style

An optional hash ref containing options for a PostScript::Graph::Style, or a PostScript::Graph::Style object.  It
should only have a B<point> group defined (line makes no sense).  (Default: green circle).

=item shown

Optional flag, true if the mark is to be shown (Default: 1)

=back

=cut

sub signal_mark_buy {
    my ($s, $id, $date, $value, $p) = @_;
    $p->{key} = "buy signal ($id)" unless defined $p->{key};

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
    
    signal_mark($s, $id, $date, $value, $p);
}

=head2 mark_buy

A convenience form of 'mark' providing a blue up arrow as the default style.  See the signal L</mark> for details.

Example

    $fsm->add_signal('buy01', 'mark_buy', undef, {
	graph => 'prices', 
	value => 440,
    });
    
=cut

sub signal_mark_sell {
    my ($s, $id, $date, $value, $p) = @_;
    $p->{key} = "sell signal ($id)" unless defined $p->{key};

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
    
    signal_mark($s, $id, $date, $value, $p);
}

=head2 mark_sell

A convenience form of 'mark' providing a red down arrow as the default style.  See the signal L</mark> for details.

Example

    $fsm->add_signal('sell01', 'mark_sell', undef, {
	graph => 'prices', 
	line  => 'high',
    });
    
=cut

sub signal_print {
    my ($msg, $id, $date, $value) = @_;
    $msg = '' if not defined $msg or ref($msg);
    print "SIGNAL $id at $date", ($msg ? ": $msg" : ''), "\n";
}

=head2 print

This is the lightweight print signal.  See L</print_values> for another which can show 'live' values.

It prints a string to STDOUT when the test evaluates 'true'.

Register the signal like this:

    $fsm->add_signal('msg1', 'print', 'Some message');

or even
    
    $fsm->add_signal('msg2', 'print');

Note that this is slighty different from all the others - there is no C<undef> (the object placeholder).
    
=cut

sub signal_print_values {
    my ($s, $id, $date, $value, $p) = @_;
    die "Cannot print value: no date\n" unless defined $date;

    my $msg = $p->{message};
    $msg = '' unless defined $msg;
    warn "No message for print_values signal\n" unless $msg;
    
    my $lines = {};
    my $masks = {};
    if (ref($p->{lines}) eq 'ARRAY') {
	my $mask = shift @{$p->{masks}};
	foreach my $i (0 .. $#{$p->{lines}}) {
	    my $full_id = $p->{lines}[$i];
	    $lines->{$full_id} = $full_id;
	    $masks->{$full_id} = defined($p->{masks}[$i]) ? $p->{masks}[$i] : '%s';
	}
    } elsif (ref($p->{lines}) eq 'HASH') {
	$lines = $p->{lines};
	$masks = $p->{masks};
    } elsif (defined $p->{lines}) {
	my $full_id = $p->{lines};
	$lines->{$full_id} = $full_id;
	$masks->{$full_id} = defined($p->{masks}) ? $p->{masks} : '%s';
    }

    while( my ($key, $full_id) = each %$lines ) {
	my $line = $s->line_by_key($full_id);
	my $v = sprintf($masks->{$key}, $line->{data}{$date});
	$v = '<undefined>' unless defined $v;
	$msg =~ s/$key/$v/gi;
    }
    $msg =~ s/\$date/$date/g;
    
    my $mask = $p->{mask};
    $mask = '%s' unless defined $mask;
    $value = sprintf($mask, $value);
    $msg =~ s/\$value/$value/gi;

    my $file = $p->{file};
    $file = \*STDOUT unless defined $file;
    
    print $file $msg, "\n";
} 

=head2 print_values

This is the heavy duty print signal.  See L</print> for a lighter weight one.

This signal is intended for constructing data files from significant events.  There is a message template which
can include line identifiers.  When the message is output for a particular date, the line values are substituted
for their identifiers.

It prints a string to a file or to STDOUT when the test evaluates 'true'.
The following parameters may be passed to B<add_signal> within a hash ref.

=over 8

=item message

This is the string that is output.  It may include C<$date> and any number of identifiers, which will
be replaced with suitable values.  Note that C<message> should be given in single quotes or with the '$' sign
escaped.  $date looks like a variable but is just a placeholder for the signal's date.

=item mask

If given this should be a B<printf> format string specifying the format of $value, e.g. '%6.2f'.

=item masks

If given, this provides a C<mask> for each of the line values.  In the same format as C<lines>.

=item lines

If a string or a reference to an array of strings, these are line identifiers, formed by concatenating the graph,
'::' and the line key.  If a hash ref is given, the line identifiers are the values associated with keys used in
C<message>.  The default line identifiers are as follows, not that spaces are allowed within the string.

    prices::opening price
    prices::closing price
    prices::lowest price
    prices::highest price
    volumes::volume

Note that a case insensitive regex match is used to pick out the identifier (or hash key) within C<message>.  So
avoid special characters as the results will not be what you expect.

[Future releases may change the graph::user_key identifiers to text identifiers as used in the model specification.]

=item file

If given, this should be an already open file handle.  It defaults to C<\*STDOUT>.

=back

Example 1

    my $fsm = new Finance::Shares::Model;

    $fsm->add_signal('value', 'print_value', undef, {
	    message => 'Signal is $value at $date', 
	});

Output the value of the test line.
	
Example 2
     
    my $fss = Finance::Shares::Sample;

    my $avgline = $fss->simple_average(
	graph => 'prices',
	period => 3,
	key => 'simple 3 day average',
    );
    
    $fsm->add_signal('note_vol', 'print_value', undef, {
	message => '$date: Volume=vv, average=avg', 
	lines   => {
	    avg => 'prices::simple 3 day average',
	    vv  => 'volumes::volume',
	},
    });

Show the value of other lines.

Example 3
   
    my $sfile;
    open $sfile, '>', 'signals.txt';
    
    $fsm->add_signal('csv', 'print_value', undef, {
	message => '$date,open,high,low,close,volume', 
	lines => {
	    open   => 'prices::opening price',
	    high   => 'prices::highest price',
	    low    => 'prices::lowest price',
	    close  => 'prices::closing price',
	    volume => 'volumes::volume',
	},
	masks   => {
	    open   => '%6.2f',
	    high   => '%6.2f',
	    low    => '%6.2f',
	    close  => '%6.2f',
	    volume => '10d',
	},
	file    => $sfile,
    });

    $fsm->test(
	graph1 => 'prices', line1 => 'close',
	graph1 => 'prices', line2 => $avgline,
	test   => 'gt',
	signal => 'csv',
    );

    close $sfile;

Construct a CSV file 'signals.txt'  holding quotes for all the dates when the signal fires.
    
=cut


sub signal_custom {
    my ($func, $id, $date, $value, @args) = @_;
    die "Not a CODE reference\n" unless ref($func) eq 'CODE';
    &$func( $id, $date, $value, @args );
}

=head2 custom

Use this to register your own callbacks which should look like this:

    sub custom_func {
	my ($id, $date, $value, @args) = @_;
	...
    }

where the parameters are:

    $id	    The identifier given to add_signal()
    $date   The date of the signal
    $value  The value of the test invoking the signal
    @args   Optional arguments given to add_signal()
    
You would register your function with a call to add_signal with 'custom' as the signal type:

    $fsm->add_signal( 'myFunc', 'custom', \&custom_func,
		      @args );
	
Example

    my $fss = new Finance::Shares::Sample(...);
    my $fsm = new Finance::Shares::Model;
    
    # A comparison line
    my $level = $fss->value(
	graph => 'volumes', value => 250000
    );

    # The callback function
    sub some_func {
	my ($id, $date, $value, @args) = @_;
	...
    }
    
    # Registering the callback
    $fsm->add_signal( 'MySignal', 'custom', \&some_func, 
	3, 'blind', $mice );

    # Do the test which may invoke the callback
    $fsm->test(
	graph1 => 'volumes', line1 => 'volume',
	graph1 => 'volumes', line2 => $level,
	test   => 'gt',
	signal => 'custom',
    );

Here &some_func will be be called with a parameter list like this when the volume moves above 250000:

    ('MySignal', '2002-07-30', 250064, 3, 'blind', $mice)

=cut

=head1 SUPPORT METHODS

=cut

sub test_sample {
    my ($o, $s, $h) = @_;
    my $id = $h->{line};
    my $label = $h->{key};
    my ($base1, $base2);
    $base1 = $s->choose_line($h->{graph1}, $h->{line1});
    die "No $h->{graph1} line with id '$h->{line1}'" unless $base1;
    die "Line '$h->{line1}' has no key" unless $base1->{key};
    if($h->{line2}) {
	my $graph2 = $h->{graph2};
	$graph2 = $h->{graph1} unless defined $graph2;
	$base2 = $s->choose_line($graph2, $h->{line2});
	die "No $graph2 line with id '$h->{line2}'\n" unless $base2;
	die "Line '$h->{line2}' has no key\n" unless $base2->{key};
	$label = (defined $testpre{$h->{test}} ? "$testpre{$h->{test}} " : '') . $base1->{key} . ' ' .
		 (defined $testname{$h->{test}} ? "$testname{$h->{test}} " : '') . $base2->{key} unless $label;
	$id = line_id("test_$h->{test}", $h->{graph1}, $h->{line1}, $graph2, $h->{line2}) unless $id;
    } else {
	$label = (defined $testpre{$h->{test}} ? "$testpre{$h->{test}} " : '') . $base1->{key} . ' ' .
		 (defined $testname{$h->{test}} ? "$testname{$h->{test}} " : '') unless $label;
	$label = "$testname{$h->{test}} $base1->{key}" unless $label;
	$id = line_id("test_$h->{test}", $h->{graph1}, $h->{line1}) unless $id;
    }
    
    my $graph = $h->{graph};
    $graph = $h->{graph1} unless defined $graph;
    my ($min, $max) = value_range( $s, $graph, $h->{weight} );
    $h->{decay} = 1 unless defined $h->{decay};
    $h->{decay} = 0 if $h->{decay} < 0;
    $h->{ramp}  = 0 unless defined $h->{ramp};
    my $data = prepare_values( $base1, $base2 );
    my @args = (%$h, sample => $s, line1 => $base1, line2 => $base2, min => $min, max => $max);
    my $res = call_function(\%testfunc,$h->{test}, $o,$data,@args );
    $s->add_line($graph, $id, $res, $label, $h->{style}, $h->{shown}) if $res;

    $h->{signals} = [ $h->{signal} ] if defined($h->{signal}) and not defined($h->{signals});
    if ($h->{signals}) {
	# A test may produce a line on one graph but invoke a 'mark' signal on another
	# The signal line may use values from the test graph axis, which might need clipping.
	foreach my $id (@{$h->{signals}}) {
	    next unless $id;
	    my $sf = $o->{sigfns}{$id};
	    next unless ref($sf) eq 'ARRAY';
	    my ($signal, $org, @rest) = @$sf;
	    if ($signal =~ /mark/) {
		my $p = $rest[0];
		my $graph = $p->{graph} || 'tests';
		my $line_id = "signal($id)";
		my $sline = $s->choose_line( $graph, $line_id, 1 );
		if ($sline) {
		    my $min = $s->{$graph}{min};
		    my $max = $s->{$graph}{max};
		    my $data = $sline->{data};
		    foreach my $date (keys %$data) {
			my $value = $data->{$date};
			$value = $min if $value < $min;
			$value = $max if $value > $max;
			$data->{$date} = $value;
		    }
		}
	    }
	}
    }
    
    return $id;
}

sub signal {
    my ($o, $ss, $obj, $date, $value) = @_;
    # changes here must be reflected in test() patch
    my $signals = ref($ss) eq 'ARRAY' ? $ss : [ $ss ];
    foreach my $id (@$signals) {
	next unless $id;
	my $sf = $o->{sigfns}{$id};
	return unless ref($sf) eq 'ARRAY';
	my ($signal, $org, @rest) = @$sf;
	$org = $obj unless defined $org;
	call_function( \%sigfunc,$signal, $org,$id,$date,$value,@rest );
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
    my $level = $a{min};
    my %res;
    foreach my $date (sort keys %$data) {
	my ($v1, $v2) = @{$data->{$date}};
	my $comp = ($v1 <=> $v2);
	if (defined $prev_comp and defined $comp) {
	    if ($prev_comp <= 0 and $comp > 0) {	# change this when copying
		$level = $a{max};
		$o->signal($a{signals}, $a{sample}, $date, $level);
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
    my $level = $a{min};
    my %res;
    foreach my $date (sort keys %$data) {
	my ($v1, $v2) = @{$data->{$date}};
	my $comp = ($v1 <=> $v2);
	if (defined $prev_comp and defined $comp) {
	    if ($prev_comp >= 0 and $comp < 0) {	# change this when copying
		$level = $a{max};
		$o->signal($a{signals}, $a{sample}, $date, $level);
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
    my $level = $a{min};
    my %res;
    foreach my $date (sort keys %$data) {
	my ($v1, $v2) = @{$data->{$date}};
	my $comp = ($v1 <=> $v2);
	if (defined $prev_comp and defined $comp) {
	    if ($prev_comp < 0 and $comp >= 0) {	# change this when copying
		$level = $a{max};
		$o->signal($a{signals}, $a{sample}, $date, $level);
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
    my $level = $a{min};
    my %res;
    foreach my $date (sort keys %$data) {
	my ($v1, $v2) = @{$data->{$date}};
	my $comp = ($v1 <=> $v2);
	if (defined $prev_comp and defined $comp) {
	    if ($prev_comp > 0 and $comp <= 0) {	# change this when copying
		$level = $a{max};
		$o->signal($a{signals}, $a{sample}, $date, $level);
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
    my $level = $a{min};
    my %res;
    foreach my $date (sort keys %$data) {
	my ($v1, $v2) = @{$data->{$date}};
	my $comp = ($v1 <=> $v2);
	if (defined $prev_comp and defined $comp) {
	    if ($prev_comp != 0 and $comp == 0) {	# change this when copying
		$level = $a{max};
		$o->signal($a{signals}, $a{sample}, $date, $level);
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
    my $level = $a{min};
    my %res;
    foreach my $date (sort keys %$data) {
	my ($v1, $v2) = @{$data->{$date}};
	my $comp = ($v1 <=> $v2);
	if (defined $prev_comp and defined $comp) {
	    if ($prev_comp == 0 and $comp != 0) {	# change this when copying
		$level = $a{max};
		$o->signal($a{signals}, $a{sample}, $date, $level);
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

sub test_min {
    my ($o, $data, %a) = @_;					# See test for list of keys

    my $lowest;
    my $prev;
    my $level = $a{min};
    my %res;
    foreach my $date (sort keys %$data) {
	my ($v1, $v2) = @{$data->{$date}};
	$level = ($v1 <= $v2 ? $v1 : $v2);
	my $line = ($v1 <=> $v2);
	$o->signal($a{signals}, $a{sample}, $date, $level) if (defined $lowest and $line and $lowest != $line);
	$level = condition_level( $level, \%a ) if (defined $prev and $prev == $level);
	$level = $a{max} if $level > $a{max};
	$level = $a{min} if $level < $a{min};
	
	$lowest = $line;
	$prev =	$res{$date} = $level;
    }

    return %res ? \%res : undef;
}

sub test_max {
    my ($o, $data, %a) = @_;					# See test for list of keys
    
    my $lowest;
    my $prev;
    my $level = $a{min};
    my %res;
    foreach my $date (sort keys %$data) {
	my ($v1, $v2) = @{$data->{$date}};
	$level = ($v1 >= $v2 ? $v1 : $v2);
	my $line = ($v1 <=> $v2);
	$o->signal($a{signals}, $a{sample}, $date, $level) if (defined $lowest and $line and $lowest != $line);
	$level = condition_level( $level, \%a ) if (defined $prev and $prev == $level);
	$level = $a{max} if $level >= $a{max};
	$level = $a{min} if $level <= $a{min};
	
	$lowest = $line;
	$prev =	$res{$date} = $level;
    }

    return %res ? \%res : undef;
}

sub test_sum {
    my ($o, $data, %a) = @_;					# See test for list of keys
    
    my $prev;
    my $level;
    my %res;
    foreach my $date (sort keys %$data) {
	my ($v1, $v2) = @{$data->{$date}};
	$level = $v1 + $v2;
	$level = condition_level( $level, \%a ) if (defined $prev and $prev == $level);
	$level = $a{max} if $level >= $a{max};
	$level = $a{min} if $level <= $a{min};
	
	$o->signal($a{signals}, $a{sample}, $date, $level) if defined $prev and $prev < $a{max} and $level == $a{max};
	$prev =	$res{$date} = $level;
    }

    return %res ? \%res : undef;
}

sub test_diff {
    my ($o, $data, %a) = @_;					# See test for list of keys
    
    my $prev;
    my $level;
    my %res;
    my $limit = defined($a{limit}) ? $a{limit} : 1;
    foreach my $date (sort keys %$data) {
	my ($v1, $v2) = @{$data->{$date}};
	$level = $v1 - $v2;

	$level = condition_level( $level, \%a ) if (defined $prev and $prev == $level);
	$level = $a{max} if $limit and $level >= $a{max};
	$level = $a{min} if $limit and $level <= $a{min};
	
	$o->signal($a{signals}, $a{sample}, $date, $level) if defined $prev and $prev < $a{max} and $level == $a{max};
	$prev =	$res{$date} = $level;
    }

    return %res ? \%res : undef;
}

sub test_or {
    my ($o, $data, %a) = @_;					# See test for list of keys
    
    my $prev;
    my $level;
    my %res;
    foreach my $date (sort keys %$data) {
	my ($v1, $v2) = @{$data->{$date}};
	$level = ($v1 || $v2) ? $a{max} : $a{min};
	
	$o->signal($a{signals}, $a{sample}, $date, $level) if defined $prev and $prev < $a{max} and $level == $a{max};
	$prev =	$res{$date} = $level unless $a{noline};
    }

    return %res ? \%res : undef;
}

sub test_and {
    my ($o, $data, %a) = @_;					# See test for list of keys
    
    my $prev;
    my $level;
    my %res;
    foreach my $date (sort keys %$data) {
	my ($v1, $v2) = @{$data->{$date}};
	$level = ($v1 && $v2) ? $a{max} : $a{min};
	
	$o->signal($a{signals}, $a{sample}, $date, $level) if defined $prev and $prev < $a{max} and $level == $a{max};
	$prev =	$res{$date} = $level unless $a{noline};
    }

    return %res ? \%res : undef;
}

sub test_not {
    my ($o, $data, %a) = @_;					# See test for list of keys
    $a{divide} = 0 unless defined $a{divide};
    
    my $prev;
    my $level;
    my %res;
    foreach my $date (sort keys %$data) {
	my ($v1) = @{$data->{$date}};
	$level = $v1 > $a{divide} ? $a{min} : $a{max};
	
	$o->signal($a{signals}, $a{sample}, $date, $level) if defined $prev and $prev < $a{max} and $level == $a{max};
	$prev =	$res{$date} = $level unless $a{noline};
    }

    return %res ? \%res : undef;
}

sub test_test {
    my ($o, $data, %a) = @_;					# See test for list of keys
    $a{divide} = 0 unless defined $a{divide};
    
    my $prev;
    my $level;
    my %res;
    foreach my $date (sort keys %$data) {
	my ($v1) = @{$data->{$date}};
	$level = $v1 > $a{divide} ? $a{max} : $a{min};
	
	$o->signal($a{signals}, $a{sample}, $date, $level) if defined $prev and $prev < $a{max} and $level == $a{max};
	$prev =	$res{$date} = $level unless $a{noline};
    }

    return %res ? \%res : undef;
}

sub ensure_psfile {
    my ($o, $filename, $of) = @_;
    die "No filename for ensure_psfile\n" unless defined $filename;
    
    if (ref($of) eq 'PostScript::File') {
	$o->{psf}{$filename} = $of;
    } else {
	$of = {} unless (ref($of) eq 'HASH');
	$of->{paper}     = 'A4' unless (defined $of->{paper});
	$of->{landscape} = 1    unless (defined $of->{landscape});
	$of->{left}      = 36   unless (defined $of->{left});
	$of->{right}     = 36   unless (defined $of->{right});
	$of->{top}       = 36   unless (defined $of->{top});
	$of->{bottom}    = 36   unless (defined $of->{bottom});
	$of->{errors}    = 1    unless (defined $of->{errors});
	$o->{psf}{$filename} = new PostScript::File( $of );
    }
}

sub resource {
    my ($o, $singular, $create) = @_;
    my $plural    = $singular . 's';
    my $default   = 'def' . $singular;
    my $order     = $singular . 'ord';
    $o->{$plural} = {};
    $o->{$order}  = [];

    my $ar = $o->{opt}{$plural};
    if (ref($ar) eq 'ARRAY') {
	$o->{$default} = $ar->[0];
	for (my $i = 0; $i <= $#$ar; $i += 2) {
	    my $id = $ar->[$i];
	    my $h  = $ar->[$i+1];
	    next unless defined $h;
	    $o->{$default} = 'default' if $id eq 'default';
	    $o->{$plural}{$id} = $h;
	    push @{$o->{$order}}, $id;
	}
    }
    
    my $h = $o->{opt}{$singular};
    if (defined $h) {
	my $name = 'default';
	$o->{$default} = $name;
	$o->{$plural}{$name} = $h;
	push @{$o->{$order}}, $name;
    }
    
    #print "${plural}: $default=$o->{$default}, order=", show_array($o->{$order}), show_hash($o->{$plural}), "\n";
} 

sub patch_signals {
    my ($o, $lines, $ss) = @_;
    my $signals = ref($ss) eq 'ARRAY' ? $ss : [ $ss ];
    foreach my $id (@$signals) {
	next unless $id;
	my $sf = $o->{sigfns}{$id};
	return unless ref($sf) eq 'ARRAY';
	my ($signal, $org, @rest) = @$sf;
	if ($signal =~ /mark/) {
	    my $h = $rest[0];
	    return unless ref($h) eq 'HASH';
	    patch_line($lines, $h, 'line');
	}
    }
}

sub out {
    my ($o, $lvl, $str) = @_;
    print STDERR "$str\n" if $lvl <= $o->{verbose};
}

### SUPPORT FUNCTIONS

sub value_range {
    my ($s, $graph, $weight) = @_;
    my ($min, $max);
    
    if ($graph eq 'tests') {
	$min = 0;
	$max = $weight;
	$max = 100 if not $max or $max > 100;
    } else {
	my $gmin = $s->{$graph}{min};
	my $gmax = $s->{$graph}{max};
	#confess "min/max not defined for $graph" unless defined $gmin and defined $gmax;
	my $margin = ($gmax - $gmin) * $points_margin;
	$min = $gmin - $margin;
	$max = $gmax + $margin;
    }

    return ($min, $max);
}

sub prepare_values {
    my ($base1, $base2) = @_;
    my ($join, $data1, $data2);
    if (defined $base2) {
	$data1 = $base1->{data} || {};
	$data2 = $base2->{data} || {};
	$join  = { %$data1, %$data2 };
	foreach my $date (keys %$join) {
	    my $v1 = $data1->{$date};
	    my $v2 = $data2->{$date};
	    if (defined $v1 and defined $v2) {
		$join->{$date} = [ $v1, $v2 ];
	    } else {
		delete $join->{$date};
	    }
	}
    } else {
	$data1 = $base1->{data} || {};
	$join  = {};
	foreach my $date (keys %$data1) {
	    my $v1 = $data1->{$date};	    # undefined values not allowed in tests
	    if (defined $v1) {
		$join->{$date} = [ $v1 ];
	    } else {
		delete $join->{$date};
	    }
	}
    }
    
    return $join;
}
# returns hash containing only values common to both lines

sub condition_level {
    my ($level, $h) = @_;

    my $lvl = $level - $h->{min};
    $lvl = $lvl*$h->{decay} + $h->{ramp};
    return $lvl + $h->{min};
}



sub patch_line {
    my ($lines, $h, $name) = @_;
    return unless defined $h->{$name};
    my $l = $lines->{'test_' . $h->{$name}};
    if (defined $l) {
	$h->{$name} = $l;
    } else {
	$l = $lines->{$h->{$name}};
	$h->{$name} = $l if defined $l;
    }
}

=head1 BUGS

The complexity of this software has seriously outstripped the testing, so there will be unfortunate interactions.
Please do let me know when you suspect something isn't right.  A short script working from a CSV file
demonstrating the problem would be very helpful.

=head1 AUTHOR

Chris Willmot, chris@willmot.org.uk

=head1 SEE ALSO

L<Finance::Shares::MySQL>,
L<Finance::Shares::Sample>,
L<Finance::Shares::Chart>.

Most models use functions from one or more of L<Finance::Shares::Averages>, L<Finance::Shares::Bands> and
L<Finance::Shares::Momentum> as well.

There is also an introduction, L<Finance::Shares::Overview> and a tutorial beginning with
L<Finance::Shares::Lesson1>.

=cut

1;

