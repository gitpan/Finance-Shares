package Finance::Shares::Code;
our $VERSION = 1.03;
use strict;
use warnings;
use Finance::Shares::Support qw(
    name_join name_split
    out out_indent show add_show_objects
);

our $MARK_START = 1;
our $MARK_SHOWN = 2;
our $MARK_HIDDEN = 3;

sub new {
    my $class = shift;
    my $o = {
	verbose => 1,
	model   => undef,
	built   => 0,
	@_,
    };
    bless $o, $class;
   
    out($o, 4, "new $class");
    return $o;
}

sub build {
    my $o = shift;
    my $q = $o->{quotes};
    my $d = $q->dates;

    out($o, 5, "build test '$o->{id}'", $o->{built} ? ' (built)' : '');
    #return @{$o->{line}} if $o->{built};
    out_indent(1);
    out($o, 2, "before=", $o->{before} || 'undef');
    out($o, 2, "step=", $o->{step} || 'undef');
    out($o, 2, "after=",  $o->{after} || 'undef');

    # ensure variables are set
    my $name = $q->chart->name;
    my $self = {
	first  => $q->{first},
	last   => $q->{last},
	start  => $q->{start},
	end    => $q->{end},
	by     => $q->{by},
	stock  => $q->{stock},
	quotes => $q,
	page   => $name,
	tag    => $o->{id},
	name   => name_join($name, $o->{id}),
	lines  => $o->{line},
	marks  => $o->{mark},
	codes  => $o->{code},
    };
    my $_o_ = $o;
    my $_c_ = $o->{code};	# used by call()
    my $_l_ = $o->{line};
    my $_v_ = [];		# control values e.g. used by mark()
    $o->{vhash} = {};		# reverse index for $_v_
    for (my $i = 0; $i <= $#$_l_; $i++) {
	my $l = $_l_->[$i];
	out($o, 2, qq(\$_l_->[$i] = ), $o->{verbose} > 2 ? $l->name : qq("$l->{key}"));
	my $fn = $l->function;
	undef $fn->{test} if $fn->isa('Finance::Shares::mark');
	$fn->build() unless $fn->built;
	my $h = {
	    first_only => $fn->{first_only},
	    state => $MARK_START,
	    next  => 0,
	    undef => 0,
	    function => $fn,
	    fsl => $l,
	};		# check mark() also, if hash contents altered
	$_v_->[$i] = $h;
	$o->{vhash}{$l->name} = $h;
    }

    # before
    if ($o->{before}) {
	out($o, 6, "evaluating 'before' code for '$o->{id}'");
	eval $o->{before};
	die $@ if ($@);
    }
    
    # compile code string into subroutine
    if ($o->{step}) {
	out($o, 6, "evaluating 'step' code for '$o->{id}'");
	my ($i, $date);
	no warnings;
	my $sub = eval "sub { $o->{step} }";
	if ($@) {
	    $@ =~ s/\(eval \d+\) //;
	    my $err = "Code error: $@";
	    $sub = sub { die $err };
	}

	# invoke subroutine for each date
	for ($i = 0; $i <= $#$d; $i++) {
	    $o->{idx} = $i;
	    $date = $d->[$i];
	    eval { &$sub };
	    die "Trouble in 'step': $@" if ($@);
	}
    }

    # after
    if ($o->{after}) {
	out($o, 6, "evaluating 'after' code for '$o->{id}'");
	eval $o->{after};
    }

    # finalize lines built during test
    for (my $i = 0; $i <= $#$_l_; $i++) {
	my $l = $_l_->[$i];
	my $fn = $l->function;
	$fn->finalize() unless $fn->built;
    }
    
    out_indent(-1);
    $o->{built} = 1;
    return @{$o->{line}};
}

sub mark {
    my ($o, $v, $i, $data, $value) = @_;
    #warn "mark(",$v || '',", $i, ",$data || '',", ",$value || '',")\n";
    unless (ref $v eq 'HASH') {
	# $v is FQLN - find/create it
	my $name = $v;
	my $fsm  = $o->{model};
	my $larray = $fsm->create_line($name, $o->{pp});
	my $l = $larray->[0];
	$data = $l->{data} if $l;
	$value = $i;
	$i = $o->{idx};
	$v = $o->{vhash}{$name};
	unless (ref $v eq 'HASH') {
	    # $v wasn't known at build time
	    my $fn = $l->function;
	    $v = {
		first_only => $fn->{first_only},
		state => $MARK_START,
		next  => 0,
		undef => 0,
		function => $fn,
		fsl => $l,
	    }
	}
    }
    die "Error in mark(), syntax is 'mark(\$mark_line, <value>)'\n" unless ref($v) eq 'HASH' and ref($data) eq 'ARRAY';

    my $start = (defined $v->{state} ? ($v->{state} == $MARK_START) : 0);
    my $false = ($i - $v->{next} > $v->{undef}) || 0;
    if ($v->{first_only}) {
	if (defined $v) {
	    if ($start) {
		if ($false) {
		    $data->[$i] = $value;
		    $v->{state} = $MARK_SHOWN;
		    $v->{next} = $i+1;
		} else {
		    $v->{next} = $i+1;
		}
	    } else {
		if ($false) {
		    $data->[$i] = $value;
		    $v->{state} = $MARK_SHOWN;
		    $v->{next} = $i+1;
		} else {
		    $v->{state} = $MARK_HIDDEN;
		    $v->{next} = $i+1;
		}
	    }
	    $v->{undef} = 0;
	} else {    # $v not defined
	    if ($v->{state} == $MARK_SHOWN) {
		$v->{state} = $MARK_HIDDEN; 
	    } else {
		$v->{undef}++;
	    }
	}
    } else {
	$data->[$i] = $value;
	$v->{state} = $MARK_SHOWN;
    }
}

sub info {
    my ($o, $v, $method, $use_fn) = @_;
    #out($o,1, "info(",$v || '', ", ", $method || '', ", ", $use_fn || '0', ")");
    my $obj;
    if (ref($v) eq 'HASH') {
	$obj = $use_fn ? $v->{function} : $v->{fsl};
    } else {
	# $v is FQLN - find/create it
	my $name = $v;
	my $fsm  = $o->{model};
	$fsm->create_line($name, $o->{pp});
	if ($v and ref($v) eq '') {
	    $obj = $fsm->known_line($v);
	    #warn "known_line=", $obj || '', "\n";
	    if ($obj) {
		# $v was name of Line
		$obj = $obj->function if $use_fn;
	    } else {
		$obj = $fsm->known_function($v);
		#warn "known_function=", $obj || '', "\n";
		if ($obj) {
		    # $v was name of Function
		    unless ($use_fn) {
			my @lines = $obj->func_lines;
			$obj = $lines[0];
		    }
		}
	    }
	}
	die "Error in info(), syntax is 'info( \$line_tag [, <method> [, use_function]] )'\n"
	    unless ref($obj) 
		and ($obj->isa('Finance::Shares::Function') or
		$obj->isa('Finance::Shares::Line'));
    }
    
    #out($o,1, "obj=", $obj || '', ", method=", $method || '');
    return $method ? $obj->$method : $obj;
}

sub call {
    my $code = shift;
    die "Error in call(), syntax is 'call('test_tag')'\n" unless ref($code) eq 'CODE';
    return &$code(@_);
}

sub value {
    my $line = shift;
    die "Error in value(), syntax is 'value(\$line_tag [, 'which_value'])'\n" unless
	(ref($line) and $line->isa('Finance::Shares::Line'));
    my $fn = $line->function;
    return $fn->value(@_);
}

__END__
=head1 NAME

Finance::Shares::Code - user programmable control

=head1 SYNOPSIS

Three examples of how to specify a test, one showing the minimum
required and the other illustrating all the possible fields.

    use Finance::Shares::Model;

    my @spec = (
	...
	tests => [
	    basic => qq( # perl code here ),
	    
	    iterative => {
		before => qq( # perl code here ),
		step => qq( # perl code here ),
		after  => qq( # perl code here ),
	    },
	    
	    code => sub { print "hello world\n" },
	],

	samples => [
	    ...
	    one => {
		tests => ['basic', 'iterative'],
		# NOT 'code' !
		...
	    }
	],
    );

    my $fsm = new Finance::Shares::Model( @spec );
    $fsm->build();

=head1 DESCRIPTION

This module allows model B<test> code to write points or lines on the graphs.

The code must be declared within a B<code> block in a L<Finance::Shares::Model>
specification.  Each test is a segment of plain text containing perl code. This
is compiled by the model engine and run as required.

Some special variables and functions provide links with the rest of the model
data.  Other lines are referenced using pseudo-variables (e.g. C<$line_tag>).
A function, C<info()> provides access to the Line and Function objects used, and
another, C<mark()> draws graph lines point by point.  Each of these uses create
their lines if they don't already exist, so a B<lines> entry is only needed if
the default behaviour isn't what you want.

Additional functions include C<value()> which is used by some
Finance::Shares::Functions to return statistics or other calculated results.

Perhaps the function with most possibilities is C<call()> which allows code to
call, at any time, methods/functions provided by other modules.

=head2 Code Types

As shown by the L<SYNOPSIS> examples, there are three types of code.

=head3 Simple text

The simplest and most common form, this perl fragment is run on every data
point in the sample where it is applied.  It can be used to produce conditional
signal marks on the charts, noting dates and prices for potential stock
positions either as printed output or by invoking a callback function.

=head3 Hash ref

This may have three keys, C<before>, C<step> and C<after>.  Each is a perl
fragment in text form. C<before> is run once, before the sample is considered.
C<step> is run for every point in the sample and is identical to L</Simple
text>.  C<after> is run once after C<step> has finished.

This form allows one-off invocation of callbacks, an open-print-close
sequence for writing signals to file, or the flexibility to write stand-alone
tests. 

To assist debugging there is an additional field, C<verbose>, which overrides
the global value.  Setting this to 2 or more shows the code fragments that are
actually evaluated.  With '2', the line substitutions are listed by their keys
while '3' lists them by their internal names.

=head3 Raw code

These are the callbacks invoked by the previous types of perl fragment.  The
parameters are those used to call the code.  See L</call> below.

=head2 Variables

In addition to perl variables declared with C<my> or C<our>, undeclared scalar
variables are used to refer to the values of other lines on the chart.

Before the code is compiled a search is made for everything that looks like
a scalar or list variable that expands to a line name.  The name is then
replaced by a reference to the internal data so that it executes correctly.

=head3 Pseudo-variables

As in the B<lines> specifications, it is possible to refer to several lines at
once.  If this is prefixed by '@', all matching values are returned as a list.
The same expression prefixed by '$' returns the first value.  [Note that it does
NOT return the number in the array.]

The special variables are as follows.

=over

=item (a)

A tag from B<names> or B<lines>;

It is important to B<avoid all variable names used by Model>.  At present these
are $open, $high, $low, $close and $volume - aliases for the
Finance::Shares::data lines.

[B<Warning> Due to the way code fragments are pre-processed, variables should
not begin with these names, either.]

=item (b)

A fully qualified line name such as

    sample1/MSFT/date1/my_tag
    sample1/MSFT/date1/bollinger/high

See L<Finance::Shares::Model/Fully Qualified Line Names> for further details.

=item (c)

A FQLN with wildcards or (some) regular expressions.

As with B<lines>, the wildcard '*' means "any (sample, stock or date) other than
this one".  Use the regular expression '.*' to match every page B<including>
the current one.

[The support for regular expressions is quite limited.  Code fragments handle
line references by rewriting (like 'C' macro pre-processing).  So to use
a regular expression as a name, it becomes necessary to search/replace a regexp
string, temporarily ignoring any special characters.   Only a few of these
are escaped at present: '$', '@', '.', '*'.  These are just enough to handle
lists of lines, the wildcard '*' and regular expression '.*'.]

=back

Otherwise the '$' or '@' value is assumed to be a valid perl variable and is
left alone.

B<Examples>

  lines => [
    avg => {
        function => 'moving_average',
    },
    boll => {
        function => 'bollinger_band',
    },
  ],

 test => q(
    $v1 = $avg;				    # normal line
    $v2 = $boll/high;			    # one of the 2 produced
    @v3 = @*/*/*/close;			    # i.e. all other close prices
    @v4 = @.*/.*//volume;		    # i.e. all volumes with this date
    $v5 = $morrison/MRW.L/default/close;    # 'close' is an alias (a 'name')
    $v6 = $morrison/MRW.L/default/boll/low; # fully qualified line name
    $v7 = $tesco///close;		    # fqln with current stock & date
    @v8 = @data;			    # all the 'data' lines
    $v9 = @data;			    # the number of 'data' lines
    $v0 = $data;			    # the first 'data' line
 ),

  samples => [
    morrison => {
        stock  => 'MRW.L',
	test   => 'default',
    },
    tesco => {
        stock  => 'TSCO.L',
	test   => 'default',
    },
  ],
  
If the variable refers (or defaults) to a line, it yields the value for the line
at that date.  Clearly this only makes sense while the test is iterating through
the data in the C<step> phase.  [If a line is referenced in C<before> or
C<after> code fragments, they return the Finance::Shares::Line object rather
than its data.]

=head3 Predefined variables

Each test also has a special variable C<$self> available.  This is a hash ref
holding persistent values (similar to an object ref, but not blessed).  A couple
of variables are declared that change with every iteration.
The following values are predefined.

=over 8

=item $date

Only useful in the C<step> phase, this is set to the current date.

=item $i

The loop counter used in the C<step> phase.  It indexes the data points.

=item $self->{by}

How the time periods are counted.  Will be one of quotes, weekdays, days, weeks,
months.

=item $self->{code}

A hash giving access to all code entries known to the model.  Using this,
subroutines registered in the code blocks can be called directly.

=item $self->{end}

The last date normally displayed on the chart.

=item $self->{first}

The first date which has data available.  The C<step> phase starts with this.

=item $self->{last}

The last date which has data available.  The C<step> phase ends with this.

=item $self->{lines}

This array lists all the source lines mentioned in this code fragment.

=item $self->{marks}

This array lists all the output lines - those referenced within B<mark()> calls.

=item $self->{name}

The fully qualified line name formed by adding the code tag to the page name.
It can be used to provide user input to an anonymous code fragment.  See
L</Portable Code>.

=item $self->{page}

This returns the string identifying the current page.

=item $self->{quotes}

This is the L<Finance::Shares::data> object used to store the dates, price and
volume data for the page.  See L<Finance::Shares::Model/Page Names>.

It should not normally be needed, but it provides a door into the engine for
those who need to access it.

=item $self->{start}

The first date normally displayed on the chart.

=item $self->{stock}

The stock code, as given to the model's B<sample> entry for this page.

=item $self->{tag}

The user defined tag identifying this code entry within a B<codes>
block.

=back

Although some effort has been made to make the code appear to be 'natural' perl,
it is worth remembering that it is not.  For example, any assignment to '$i'
will not stick (the model uses it as the iteration counter).

If something won't parse try putting in a space after the pseudo-variable or
using concatenation rather than embedding.  You can view the code that is
actually evaluated - i.e. after the preprocessor substitutions - by setting the
C<verbose> option to 2 or more.

=head2 Marking the Chart

A special function is provided which will add a point to a chart line.  It is
called as

    mark( tag, value )

=over 8

=item C<tag>

This must refer to B<lines> block entry which has C<mark> as the function field.
[It may be a string literal or a run-time variable.  But see L</Information on
Other Lines>.]

=item C<value>

A perl expression evaluating to a number or undefined.  Often a pseudo-scalar
variable refering to a line.  See L</Variables> above.

=back

B<Example>

    lines => [
	circle => {
	    function => 'mark',
	},
	average => {
	    function => 'moving_average',
	},
    ],

    code => [
	show => q(
	    mark('circle', $average);
	),
    ],

    sample => {
	test => 'show',
    },

In this example the moving average line is marked twice.  As well as the normal
line, the C<show> test is invoked and a circle (the default mark) is placed at
every position where C<average> is defined.

Notice that the engine invokes the moving average function for you as it is
referred to in the test.  There is no need to list it explicitly as a line.

=head2 Information on Other Lines

As most code works on data in other lines, it is useful to be able to access
information from other L<Finance::Shares::Function> and L<Finance::Shares::Line>
objects.  This is done using the special function, B<info>.

    info( <tag> [, <method> [, <use_fn> ]] )

=over

=item <tag>

Identifies the line/function in question.  It can be a fully qualified line
name either as a literal in quotes, a pseudo-variable beginning with '$' or
a proper variable.

So the following are legal calls where C<tag> is a B<lines> identifier, C<line>
is a suitable line identifier (e.g. 'default') and C<$fqln> is a variable
holding a fully qualified line name (see L<Finance::Shares::Model/Fully
Qualified Line Names>).

    info( 'tag' )
    info( $tag )
    info( 'tag/line' )
    info( $tag/line )
    info( $fqln )

=over

[WARNING: The variable form is the most problematic.  As the line's identity
isn't known at compile time, there is no way to ensure it has been built, and it
doesn't take part in the internal checks.  Also, literal tags can be looked up
at compile time, but the variable form must be looked up and every time the code is
run.  So avoid using variables as identifiers in C<step> sections.]

=back

=item <method>

This should be the name of a method from either
L<Finance::Shares::Function> or L<Finance::Shares::Line> classes.  At present,
only methods without arguments can be called, but these are enough for most
purposes.

Function methods include:
    
    Method	    Returns
    -------------------------------------------------------
    id		    lines tag identifying the specification
    name	    FQLN, i.e. sample/stock/date/id
    chart	    Finance::Shares::Chart object
    model	    Finance::Shares::Model object
    line_ids	    list of dependent line tags/fqlns
    func_lines	    list of created Finance::Shares::Lines
    source_lines    structured list of FS::Lines used
    sources	    flat list of Finance::Shares::Lines
    value	    [better to use the value() call]
    finalize	    ensure graph axis fit around lines

Line methods include:

    Method	    Returns
    -------------------------------------------------------
    id		    the line identifier
    name	    FQLN, i.e. sample/stock/date/tag/id
    data	    array of values for calculations
    display	    array of values for display (as data)
    npoints	    number of data points
    function	    the parent Finance::Shares::Function
    chart	    Finance::Shares::Chart object
    graph	    hash ref holding graph settings
    order	    Z-order display position in graph
    for_scaling	    true if line doesn't match Y axis
    is_mark	    true if line is generated from code

If C<method> is omitted, the object reference itself is returned.

=item <use_fn>

The function can return information on either Lines or Functions.  If omitted
(or false) C<tag> is assumed to be a Finance::Shares::Line object.  Setting this
to true means that the C<method> will be called on the Finance::Shares::Function
object that created it.

Where C<tag> is completely explicit, it refers to a Line and there is no
confusion.  But if C<tag> evaluates to a FQLN without a line identifier, this is
assumed to be a Function (NOT the 'default' line).  If, in this case, C<use_fn>
is not set, C<method> is called on the FIRST created line.  For example,

    info() call		    Returns
    -------------------------------------------------------
    info($tag)		    first FS::Line object
    info($tag/line)	    the FS::Line object requested
    info($tag,,1)	    the FS::Function object
    info($tag,'name')	    FQLN of the first line
    info($tag/line,'name')  calls the Line's 'name' method
    info($tag,'name',1)	    the Function's 'name' method

=back

=head3 value( <tag> [, <which_value>] )

A poor relation of the other functions, this just calls the C<value> method of
the indicated Finance::Shares::Function. (The parent Function is used if a Line
tag is given.)  C<tag> must be a pseudo-variable i.e. a tag name preceded by
a '$'.

Some Functions (e.g. F<sample_mean>) just provide a single value, but others
(e.g. F<standard_deviation>) produce several.  In that case, it is necessary to
pass a string indicating which.

    my $max = value($max_line);
    my $sd  = value($sd_line, 'std_dev');

=over

[The line is NOT created when referenced here.  This isn't a problem as the
Function normally requires a B<lines> entry.  But if it is, use the line name as
a pseudo-variable or do an C<info()> or C<mark()> call on it first to ensure it
exists.

[This interface is likely to change so that it catches up with the others.]

=back

=head2 Portable Code

The line/function tag may be a variable, provided that variable holds a fully
qualified line name.  This makes for portable code if used in conjunction with
C<$self->{name}> which holds the FQLN for the code.  For example,

    my $func  = info($self->{name}, 'function');
    my @lines = info($self->{name}, 'func_lines', 1);

These require a B<lines> tag with the same name as the B<code> tag containing
it.  Thus code can be stored in a file and used in any model, B<provided the code
and line entries use the same tag name>.

B<Example>

The file F<band.code> contains a B<code> hash with C<before>, C<step> and
C<after> code.

    {
	before => q(
	    # Access the 'offset' field given in the lines entry
	    my $fn          = info($self->{name}, 'function');
	    $self->{offset} = $fn->{offset} || 5;

	    # Identify the single source line
	    my @lines       = info($self->{name}, 'sources', 1);
	    $self->{source} = $lines[0];

	    # Other prior working to keep the step code simple
	    $self->{high}   = $self->{name} . '/high';
	    $self->{low}    = $self->{name} . '/low';
	),
	step => q(
	    # The line's value is the i'th in the 'data' array
	    my $array = $self->{source}->data;
	    my $value = $array->[$i];

	    # Only add to the line if the value exists
	    if (defined $value) {
		mark($self->{high}, $value + $self->{offset});
		mark($self->{low} , $value - $self->{offset});
	    }
	),
	after => q(
	    # Ensure the rest of the model knows about this data
	    info($self->{name}, 'finalize', 1);
	),
    }

A model specification using this might then include:

    code => [
	my_tag => do('band.code'),
	...
    ],
    
    lines => [
	my_tag => {
	    line   => 'open',
	    offset => 3,
	    out    => ['high', 'low'],
	},
    ],

    sample => {
	code => ['my_tag'],
	line => ['my_tag'],
    },
    
This then produces two lines 3 above and 3 below each date's closing price.

=over

[The field C<lines=E<gt>my_tag=E<gt>out> is optional.  However, without it a 'default' line
will be created at the first C<info()> call, and it will clutter up the chart's
Key.

Likewise, the inclusion of C<my_tag> in C<sample=E<gt>line> is optional but
recommended.  Without it, the line is unknown to the system and the dependencies
could well become confused.]

=back

=head2 Calling Foreign Code

Model B<code> entries may be code refs as well as text.  The code is then called
using a special function, which will return whatever the code returns.

             call( tag, arguments )
    scalar = call( tag, arguments )
    list   = call( tag, arguments )

=over 8

=item C<tag>

This must be a tag in a B<tests> block identifying a code ref.

=item C<arguments>

This list of arguments (or none) is passed to the subroutine identified by
C<tag>.

=back

B<Example>

    tests => [
	tcode => {
	    my $v = shift;
	    print "$v->{stock} quotes from $v->{first}\n";
	},
	doit => {
	    before => q(
		call('tcode', $self);
	    ),
	},
    ],

    sample => {
	test => 'doit',
    },

Remember that C<$self> has a number of predefined fields, C<{stock}> and
C<{first}> among them.  The C<before> code is only invoked at the start of the
test.  It calls the subroutine which prints a message.

This might seem an involved way to go about it, but it is extremely powerful.
The subroutine call is made within code which has all the model values (as well
as the complete power of perl) available.  It may be passed whatever values you
choose.

B<Example>

This is a slightly more useful example.  It assumes that the MyPortfolio module
has exported subroutines defined for simulating buying/selling shares and
keeping track of positions you hold in the market.  A 'buy' call is made when
the stock price seems to rise.

    # declare function modules used
    use Finance::Shares::moving_average;
    
    # import callback from another module
    use MyPortFolio 'enter_long_position';

    # Model specification begins
    ...
    
    lines => [
	fast => {
	    function => 'moving_average',
	    period   => 5,
	},
	slow => {
	    function => 'moving_average',
	    period   => 20,
	},
    ],

    tests => [
	buy  => &enter_long_position,
	code => q(
	    call('buy', 'pf1', $self->{date}, $low, $high)
		    if $fast >= $slow;
	);
    ],

    sample => {
	test => 'code',
    },

When the 5 day moving average crosses above the 20 day one, the callback is
invoked.  It will be passed a portfolio ID, the date, lowest and highest proces
for the day.

<realism> A buy signal would need to be invoked on the basis if at least
yesterday's data as todays is usually not yet known!  This might be done by
using a $self->{buy} flag and having C<after =E<gt> 1> set in the appropriate
B<dates> entry. </realism>

=head1 BUGS

These lines are reserved: $open, $high, $low, $close, $volume.  If a test uses
a tag name starting with any of these, it will get confused.

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
L<Finance::Shares::Function> and L<Finance::Shares::Line>.
Also, L<Finance::Shares::Code> covers writing your own tests.

=cut


