package Finance::Shares::Function;
our $VERSION = 1.00;
use strict;
use warnings;
use Log::Agent;
use Finance::Shares::Support qw(
	$highest_int $lowest_int
	valid_gtype name_join extract_list
	out out_indent show
    );
use Finance::Shares::Line;
use Finance::Shares::Model;

our $monotonic = 0;	# for auto-numbering display order

=head1 NAME

Finance::Shares::Function - Base class for function objects

=head1 SYNOPSIS

    use Finance::Shares::Function;

Data access

    $name   = $fn->id();
    $name   = $fn->name();
    $fsc    = $fn->chart();
    @names  = $fn->line_ids();
    $fsl    = $fn->line($name);
    @fsls   = $fn->lines();
    @fsls   = $fn->source_lines();
    $string = $fn->show_lines();

These functions should be implimented by any inheriting class.

    $fn->initialize();
    $fn->build();
    $n = $fn->lead_time();
    
=head1 DESCRIPTION

All data, lines or points that appear on a Finance::Shares::Chart are
Finance::Shares::Lines generated by a class named something like
Finance::Shares::<function>.  They are all inherit from this class.

Most Finance::Shares::Function classes will only generate one
Finance::Shares::Line but some have several.  All lines belonging to a function
are built at the same time - so all are available once one line has been
requested.

The Functions are created by L<Finance::Shares::Model> which supervises their
use.  The only methods documented here are those of use to writers of function
modules.

=head2 How to Write a Function Module

Apart from a constructor (which must be called B<new>), the methods
B<initialize>, B<build> and possible B<lead_time> should be implemented.
This is best illustrated with an example.

=head3 Initialization

The code presented here is for a module L<Finance::Shares::my_module>.  It
is found in a file called F<my_module.pm> and begins quite normally.

    package Finance::Shares::my_module;
    use strict;
    use warnings;
    use Log::Agent;
    use Finance::Shares::Support qw(out);
    use Finance::Shares::Function;
    our @ISA = 'Finance::Shares::Function';

Perhaps the only thing that needs comment is L<Log::Agent>.  The whole suite
uses this to output feedback and debugging messages.
    
=head3 The Constructor

Almost every constructor is the same.

    sub new {
	my $class = shift;
	my $o = new Finance::Shares::Function(@_);
	bless $o, $class;

	out($o, 4, "new $class");
	return $o;
    }

All functions inherit from L<Finance::Shares::Function>.  I use C<$o> instead of
C<$self> as it is less to type, is rarely used and stands for $object.  What you
use is up to you.

The B<out()> line sends a debug message to L<Log::Agent> provided the B<verbose>
level is greater or equal to 4.  See L<fsmodel> or L<Finance::Shares::Model> for
details.
    
=head3 initialize()

The module will produce a line on an 'analysis' graph and requires two source
lines to work on.

    sub initialize {
	my $o = shift;

	$o->common_defaults('analysis', 'close', 'open');

	$o->add_line('result', 
	    gtype  => $o->{gtype},
	    graph  => $o->{graph},

	    key    => $o->{key} || '',
	    style  => $o->{style},
	    shown  => $o->{shown},
	    order  => $o->{order},
	);
    }

The model engine, L<Finance::Shares::Model>, creates the my_module object and
passes the user parameters to it (the fields given in the relevant B<lines>
entry of the model spec).  The parameters all become fields in the object hash,
and some are passed on the the result line, as shown.

The B<initialize> method provides the opportunity to validate or tidy up the
user options, set any defaults required and prepare any lines that other
functions might make use of.  Using B<common_defaults> ensures that the function
works like others, so the user knows what to expect.

B<add_line> creates the L<Finance::Shares::Line> that will hold the function's
results.  Most of the valid options are passed to it.  Note that C<key> is given
an empty string as the default value.  This is used by B<build>, when
information from the source lines is available.

=head3 build()

This is the business method, where all the calculations are done.  Being larger,
we will consider it in sections.

    sub build {
	my $o = shift;
	my $q = $o->{quotes};
	my $d = $q->dates;

Some definitions needed later.  Notice that the L<Finance::Shares::data> object
for the line's chart page is available through C<$o-E<gt>{quotes}>.  Iterating
through its dates is the best way to generate most lines.

	my $first = $o->{line}[0][0];
	my $second = $o->{line}[1][0];
	my $d1 = $first->{data};
	my $d2 = $second->{data};
	
Notice that C<{line}> is a nested array.

The B<lines> entries in the model spec actually define B<functions> like
'greater_than' (rather than graph lines - confusing, I know).  It is quite legal
for a single function to produce several graph lines, such as an upper and lower
bound on a range.  The lines generated by each function are returned as an array
ref so that the sequence of lines generated matches those requested.

For example, say the user specified the following, with 'this' and 'that' being
dependent lines.
    
    lines => [
	myline => {
	    function => 'myfunction',
	    lines => ['this', 'that'],
	},
    ],

If 'this' produced a single line and 'that' produced three, they would later be
accessed by:

    $o->{line}[0][0]	'this'

    $o->{line}[1][0]	'that'
    $o->{line}[1][1]
    $o->{line}[1][2]

Anyway, back to the B<build> method.  C<$first> and C<$second> are
L<Finance::Share::Line> objects that have already been processed, so their
C<{data}> fields (C<$d1> and C<$d2>) hold arrays of values, one per date.

    my (@points, $level);
    for (my $i = 0; $i <= $#$d; $i++) {
	my $result;
	my $value1 = $d1->[$i];
	my $value2 = $d2->[$i];
	
	if (defined $value1 and defined $value2) {
	    #
	    # calculate $level;
	    #
	    $result = $level;
	}
	
	push @points, $result;
    }

Inside the loop, details of the 'greater_than' calculations have been omitted to
make the common points clearer.

Notice that whatever happens, a value is pushed onto C<@points> for every date.
It might be a calulated value, or C<undef>.  It is often useful to seperately
keep track of the last valid value (C<$level> here).
	
When the loop has finished, the result line can be updated with the new data and
B<build> returns.

      my $l = $o->line('result');
      $l->{data} = \@points;

      $l->{key} = "'$first->{key}' > '$second->{key}'"
	unless $l->{key};
    }


=head2 Compound Functions

The more interesting functions are made from combining other lines.  To be
useful these lines must be generated within the main function, rather than
relying on the user to specify them.

The Model engine has two main phases.  During the 'create' phase, the samples
are analysed and all the objects that will be required are created.  [In
particular L<Finance::Shares::Function> and
L<Finance::Shares::Line> objects from explicitly named lines and those they
depend on.]  The 'build' phase then visits these, filling out the data
by calculating each Function as required.

During 'create' the Functions are called top-down: each one
is inspected and any dependent lines are then created.  'build' works the other
way round.  When each function is built, it can rely on all the dependent lines
being complete.  

The B<initialize> method is called during 'create' and B<build> during 'build',
naturally enough.  This means new line specifications can be declared in
B<initialize>, fooling the Model engine into thinking they were there all the
time.  But there is a slight problem with this.  Because the Model
didn't ask for these additional functions, it isn't aware they need to be built
either.  So the B<build> method must make sure any additional lines are built
before it does any calculations on them.

The example followed here comes uses the 'gradient' function in its
calculations.  See L<Finance::Shares::rising> as an example.

=head3 initialize()

Once all the parameters' defaults have been sorted out, a new entry is sneakily
added into the B<lines> model specification.

First, the entry will need a tag.  It is assumed that C<{line}> has just one
source line and that is converted to a gradient.  So the name of the source line
is recorded and the new tag name becomes the dependent line.
	
	my $tag       = unique_name( 'gradient' );
	my $source    = $o->{line}[0];
	$o->{line}[0] = $tag;

	my ($shown, $style) = shown_style( $o->{gradient} );

A user field ('gradient') is passed to B<show_style> which interprets options
for displaying the underlying line:

=over

=item '0'

The line is hidden.

=item '1'

The line is visible with the default style.

=item hash ref

The line uses a style created from this specification.

=item L<PostScript::Graph::Style> object

The line is shown with the style given.

=back

B<unique_name> and B<show_style> are support functions which adds an initial
underscore and a trailing unique number to the given stem.  It is declared in
the Support module, so this 'use' line will be required at the start.

    use Finance::Shares::Support qw(out
				    unique_name
				    show_style);

C<$h> holds the model spec B<lines> options, plus some required fields
(C<function> and C<uname>).

	my $h = {
	    function => 'gradient',
	    uname    => $tag,

	    line     => [ $source ],
	    shown    => $shown,
	    style    => $style,
	    strict   => $o->{strict},
	    period   => $o->{period},
	};
	
With C<$h> complete, the specification can be added to the model's options.

	my $data = $o->{quotes};
	my $fsm  = $data->model;
	$fsm->add_option('lines', $uname, $h);

Now the source lines have been sorted out, the rest of B<initialize> can be
completed.  This usually just means calling B<add_line> to create the
L<Finance::Shares::Line> object(s) that will hold the results of your Function.

=head3 lead_time()

The model engine now has a B<lines> options entry filled out and the functions
C<line> field showing the new line as a dependent.  It will therefore handle the
inserted line normally.  This means that B<lead_time> should only reflect
my_module's own calculations - the C<gradient> lead time will be handled by its
own function in the normal way.

=head3 build()

Nothing special needs to be done in the 'build' phase as the dependent lines
should have been built in the right order.

One little quirk is worth mentioning.  It is common for the dependent line's key
to be quoted in the key for the results line.  But of course the source line the
user gave is now the 'grandchild' of this function.  The problem is overcome by
accessing the source line(s) of the inserted function.

In this case, the inserted function is C<gradient> and is in position 0;
C<gradient> only produces one line, so

    my $grad_line = $o->{line}[0][0];
    
    my $grad_fn   = $grad_line->function();
    my @src_lines = $grad_fn->source_lines();
    
Only one source function is expected and that only has one line, so again
    
    my $src_key   = $src_lines[0][0]{key};
   
=cut

sub new {
    my $class = shift;
    my $o = {
	verbose => 1,
	id      => '',    # user name given in model spec
	fsc   => undef, # Finance::Shares::Chart object showing quotes

	lnames  => [],    # set by add_line()
	fsls    => [],	  # set by add_line()
	built   => 0,	  # set by finalize()
    };
    
    bless( $o, $class );
    $o->add_parameters( @_ );

    return $o;
}

=head1 METHODS

=cut

sub add_parameters {
    my $o = shift;
    for( my $i= 0; $i <= $#_; $i += 2) {
	my $key    = $_[$i];
	my $value  = $_[$i+1];
	$o->{$key} = $value;
    }

    $o->initialize;
}

# Add parameters to the function.  C<param_list> is a list of hash keys and
# values.

sub initialize {
}

=head2 initialize( )

Override this to initialize the object.  For example, use this to ensure needed values have suitable defaults.  

Due to the way functions are created by the model, no parameters of consequence are given to the constructor.
They are passed using an internal call to B<add_parameters>, which finishes by calling B<init>, which by default
does nothing.

=cut

sub common_defaults {
    my ($o, $gtype, @lines) = @_;
    $o->{quotes} = $o->{fsc}->data if $o->{fsc};

    $o->{gtype} = $gtype unless defined $o->{gtype};
    my $g = $o->{fsc}->graph_for($o);
    $o->{gtype} = $g->{gtype} unless defined $o->{gtype};
    $o->{graph} = $g->{graph} unless defined $o->{graph};
    logerr("'$o->{gtype}' is not a valid graph type") unless valid_gtype $o->{gtype};

    $o->{shown} = 1 unless defined $o->{shown};
    
    my @given  = (ref($o->{line}) eq 'ARRAY') ? @{$o->{line}} : (defined($o->{line}) ? $o->{line} : ());
    $o->{line} = (@lines ? \@lines : [ 'data/close' ]) unless @given;
}

=head2 common_defaults( [gtype [, line(s)]] )

This method provides some default settings which might be useful within B<initialize>.

C<gtype> becomes a default graph type. (Default: 'price').

C<line(s)> is a list of zero or more line names.   Either simple line tags as given in the model specification, or
in the form <function>/<line>.  These are used as a default for the
C<line> option (Default: 'data/close').

C<shown> is also set depending on whether a C<style> value was declared.

It also sets a new field {quotes} which points to the chart's price and volume data.

=cut

sub level_defaults {
    my ($o, $weight, $decay, $ramp) = @_;

    $weight = 100 unless defined $weight;
    $decay  = 1   unless defined $decay;
    $ramp   = 0   unless defined $ramp;
    $o->{weight} = $weight unless defined $o->{weight};
    $o->{decay} = $decay  unless defined $o->{decay};
    $o->{ramp}  = $ramp   unless defined $o->{ramp};
}

=head2 level_defaults( [decay [, ramp]] )

Ensure suitable defaults for functions intended for the 'level' graph type.

=cut


sub lead_time {
    return 0;
}

=head2 lead_time( )

Override this if the function requires any periods of working prior to the first requested date.  This default
method returns 0.

=cut

sub longest_lead_time {
    my ($o, $path) = @_;
    $path = {} unless defined $path;
    $path->{$o}++;
    
    my $max = 0;
    return 0 unless ref($o->{line}) eq 'ARRAY';
    out($o, 6, "longest_lead_time for ", $o->name);
    my @list;
    foreach my $ar (@{$o->{line}}) {
	push @list, extract_list( $ar );
    }
    
    out_indent(1);
    foreach my $line (@list) {
	my $func = $line->function;
	my $lead = ($path->{$func} ? 0 : $func->longest_lead_time);
	$max = $lead if $lead > $max;
    }
    out_indent(-1);

    my $all = $max + $o->lead_time();
    out($o, 6, "longest_lead_time for ", $o->name, " = $all");
    return $all;
}

# Whereas B<lead_time> returns the number of prior periods required for this Function's working,
# B<longest_lead_time> returns the lead time of this and all dependent functions.
# 
# The default implementation returns this object's lead_time plus the longest longest_lead_time amongst all
# dependent lines.
# 
# B<Example>
# 
# In this rather contrived example, the longest_lead_time would be 30.  'long' will produce 20+10 and 'comp'
# chooses the longest between 30 and 5.
# 
#     functions => [
# 	boll => {
# 	    function => 'bollinger/high',
# 	    period   => 20,
# 	},
# 	short => {
# 	    function => 'moving_average',
# 	    period   => 5,
# 	},
# 	long => {
# 	    function => 'moving_average',
# 	    lines    => ['boll'],
# 	    period   => 10,
# 	},
# 	comp => {
# 	    function => 'gt',
# 	    lines    => [qw(short long)],
# 	},
#     ],

sub build {
    my $o = shift;
    logdie "$o has no 'build' method!";
}

# Override this to calculate the result line(s).  Usually requires the values
# passed to B<add_parameters>.  C<chart> is the Finance::Shares::Chart object
# where the function belongs.  The Finance::Shares::data holding the chart's
# prices and volumes is accessible through
# 
#     my $data = $chart->data();

sub finalize {
    my $o = shift;
    out($o, 6, "finalizing Function ", $o->name);
    out_indent(1);
    foreach my $line ($o->lines) {
	$line->finalize();
    }
    out_indent(-1);
    $o->{built}++;
}

# A convenience method calling B<finalize> for each line.  There is no need to
# call this if the Finance::Shares::Line method was called when each line was
# built.

=head1 ACCESS METHODS

=cut

sub id {
    return $_[0]->{id};
}

=head2 id( )

Return the user tag identifying the definitions in the model B<lines>
specification.

=cut

sub name {
    my $o = shift;
    return name_join( $o->{fsc}->name, , $o->{id} );
}

=head2 name( )

Return the canonical name for this function.

=cut

sub chart {
    return $_[0]->{fsc};
}

=head2 chart( )

Return the Finance::Shares::Chart object displaying this function.

=cut

sub model {
    return $_[0]->{fsc}->model;
}

=head2 model( )

Return the Finance::Shares::Model engine.

=cut

sub line_ids {
    return @{$_[0]->{lnames}};
}

=head2 line_ids( )

Return a list of the keys used to identify the Lines created by the function.
Override this if the function generates more than one line.  This default method
returns ''.

Note that this lists the B<result> lines and is nothing to do with the C<line>
option. C<line> lists the B<source> lines this function depends on.

=cut

sub line {
    my ($o, $lname) = @_;
    return $o->{fsls}[0] unless $lname;
    my $lnames = $o->{lnames};
    for (my $i = 0; $i <= $#$lnames; $i++) {
	return $o->{fsls}[$i] if $o->{lnames}[$i] eq $lname;
    }
    return undef;
}

=head2 line( id )

Return the Finance::Shares::Line identified by the tag C<id>.  If C<id> is
omitted, the first id returned by B<line_ids> is assumed.  Note that the leaf
name is expected, rather than the full line name.

=cut

sub lines {
    my $o = shift;
    return @{$o->{fsls}};
}

=head2 lines( )

Returns a list of all the Finance::Shares::Line objects generated by this
function.

=cut

sub line_list {
    my ($o, $id) = @_;
    $id = '*' unless $id;
    $id = '.*' if $id eq '*';
    my @found;
    my $lnames = $o->{lnames};
    for (my $i = 0; $i <= $#$lnames; $i++) {
	my $name = $lnames->[$i];
	push @found, $o->{fsls}[$i] if $name =~ /$id/;
    }
    return \@found;
}

=head2 line_list( regexp )

C<regexp> should match the last (fnline) portion of the full line name.  If
omitted, or '*', all lines are matched.  An array ref is returned holding the
list of found line objects.

=cut

sub source_lines {
    my $o = shift;
    return @{$o->{line}};
}

=head2 source_lines( )

Return a list of the Finance::Shares::Line objects used as a source
lines.

=cut

=head1 SUPPORT METHODS

=cut

sub add_line {
    my $o = shift;
    my $line_id = shift;
    logerr("No ID field for add_line()"), return unless defined $line_id;
    
    logerr(ref($o) . " '$o->{id}' already has a line '$line_id'"), return if $o->{fnlines}{$line_id};
    my $line = Finance::Shares::Line->new(
	fsfn     => $o,
	id       => $line_id,
	verbose  => $o->{verbose},
	@_
    );
    
    push @{$o->{lnames}}, $line_id;
    push @{$o->{fsls}},   $line;
    $line->initialize();

    return $line;
} 
=head2 add_line( id, @options )

Add a line to the function under the identifer C<id>.  It should be followed by
a list of options in hash key => value format.  This constructs
a L<Finance::Shares::Line> object accessible as:

    $fn->line( $id )

=cut

sub show_lines {
    my $o = shift;
    my $res = '';
    my $lnames = $o->{lnames};
    for (my $i = 0; $i <= $#$lnames; $i++) {
	my $line = $o->{fsls}[$i];
	$res .= $line->name;
	$res .= ', ' if $i < $#$lnames;
    }
    return $res;
}

=head2 show_lines( )

Return a string holding the fully qualified line names of all the source lines.
See also L<Finance::Shares::Support/show> for another very useful debugging
function.

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

