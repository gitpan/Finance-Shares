package Finance::Shares::mark;
our $VERSION = 1.03;
use strict;
use warnings;
use Finance::Shares::Support qw(out out_indent show);
use Finance::Shares::Function;
use Log::Agent;
our @ISA = 'Finance::Shares::Function';

sub new {
    my $class = shift;
    my $o = new Finance::Shares::Function(@_);

    $o->{check} = {};

    bless $o, $class;

    out($o, 4, "new $class");
    return $o;
}

sub initialize {
    my $o = shift;

    $o->common_defaults; # how to unset line?

    my $style = $o->{style};
    if ($style and ref $style eq '') {
	if ($style eq 'circle') {
	    $o->{size} = 12 unless defined $o->{size};
	    $o->{style} = {
		bgnd_outline => 1,
		point => {
		    shape => 'circle',
		    size  => $o->{size},
		    width => $o->{size}/6,
		},
	    };
	} elsif ($style eq 'up_arrow') {
	    $o->{size} = 8 unless defined $o->{size};
	    $o->{style} = {
		point => {
		    shape => 'north',
		    size  => $o->{size},
		    width => $o->{size}/5,
		    y_offset => -$o->{size},
		},
	    };
	} elsif ($style eq 'down_arrow') {
	    $o->{size} = 8 unless defined $o->{size};
	    $o->{style} = {
		point => {
		    shape => 'south',
		    size  => $o->{size},
		    width => $o->{size}/5,
		    y_offset => $o->{size},
		},
	    };
	}
    }
    
    $o->{out} = $o->{requested} || 'default' unless $o->{out};
    #warn "{out}=", $o->{out} || '<undef>';
    $o->{out} = [ $o->{out} ] unless ref($o->{out}) eq 'ARRAY';
    if ($o->{requested}) {
	my $found = 0;
	foreach my $lname (@{$o->{out}}) {
	    $found++, last if $lname eq $o->{requested};
	}
	push @{$o->{out}}, $o->{requested} unless $found;
    }
    #warn "@ {out}=", join(',',@{$o->{out}});
    my @out = @{$o->{out}};
    push @out, $o->{requested} if $o->{requested};
    my %check = map { ($_, 0) } @out;
    #$o->additional_line( $o->{requested} || $o->{out}[0] );
    foreach my $out (@out) {
	$o->additional_line( $out ) unless $check{$out};
	$check{out}++;
    }
}

sub additional_line {
    my ($o, $out) = @_;
    return unless $out;
    #out($o,1, "additional_line($out)");
    return if $o->{check}{$out};

    my $key_stem = $o->{stem} || $o->{id};
    my $default_key = ($out =~ /default/) ? $key_stem : "$key_stem/$out";
    $o->add_line( $out, 
	graph  => $o->{graph},
	gtype  => $o->{gtype},
	key    => $o->{key} || "'$default_key'",
	style  => $o->{style},
	shown  => $o->{shown},
	order  => $o->{order},
    );
    $o->{check}{$out}++;
}

sub build {
    my $o = shift;
    out($o, 5, "building mark");

    foreach my $l ($o->func_lines) {
	$l->{data} = [];
    }
    
    my $test = $o->{test};
    $test->build() if ref($test) and $test->isa('Finance::Shares::Code');
}

__END__
=head1 NAME

Finance::Shares::mark - A line under user program control

=head1 SYNOPSIS

Two examples of how to specify a mark line, one showing the minimum
required and the other illustrating all the possible fields.

    use Finance::Shares::Model;
    use Finance::Shares::mark;

    my @spec = (
	...
	lines => [
	    minimal => {
		function => 'mark',
	    },
	    full = {
		function   => 'mark',
		use_spec   => 1,
		graph      => 'Stock Prices',
		gtype      => 'price',
		first_only => 1,
		key        => 'these are special',
		style      => { ... },
		shown      => 1,
		order      => 99,
	    },
	],
	
	tests => [
	    t1 => q( mark($full, 300) ),
	],
	
	samples => [
	    ...
	    one => {
		test => 't1',
		...
	    }
	],
    );

    my $fsm = new Finance::Shares::Model( @spec );
    $fsm->build();

=head1 DESCRIPTION

This module allows model B<test> code to write points or lines on the graphs.

Significant options are B<line>, B<first_only>, B<style> and B<size>.

=head2 Call Syntax

This module may be treated like any other B<line>, but it has some additional
features.

The L<Finance::Shares::Model> specification B<lines> entry is not required, but
may be useful.  Normally the entry's tag would be used in a B<code> fragment.

    mark( "line_tag", $position );
    mark( "line_tag/out_tag", $position );

Here C<line_tag> is the B<lines> entry tag and C<out_tag> is an identifier for the
output line.  This must be inside either single or double quotes.  C<$position>
should evaluate to a Y axis value.  It may be another line tag or an ordinary
Perl expression.

B<Example>

    lines => [
	low10 = {
	    function => 'lowest',
	    period   => 10,
	    key      => '10 day low',
	}
	output => {
	},
    ],

    code => [
	example1 => q(
	    mark( 'output', 115 );
	),
	example2 => {
	    before => 'my $line = $output;'
	    step   => 'mark( "output", $low10 );'
	},
	example3 => {
	    before => q(
		my $line1 = $output/low;
		my $line2 = $output/high;
	    ),
	    step   => q(
		mark( "output/low",  $close - 10 );
		mark( "output/high", $close + 10 );
	    ),
	},

	# Asking for TROUBLE
	example4 => q(
	    my $line = $output/main;
	    mark( 'output', $low10 + 5 );
	),
    ],

=head2 Some Gotchas

Although the default values are useful, mixing defaults and given identifiers
can lead to confusion.  To be on the safe side, stick to the following
usage.

=head3 Using the default line

It is not necessary to give the line a name if there is only ever going to be
one.  That is, all B<mark> calls add points on the same line.  And if the line
is referenced seperately as in 'example2', it is referring to that line.

=head3 Multiple lines

Where the code produces multiple lines, give each line an explicit 'out' tag.
Here it is better to always specify the line identifier as in 'example3'.

Mixing the two styles ('example4') is not a good idea.  If necessary, the order
of lines can be controlled by giving and C<out> field in the B<lines>
specification.  In that case, the first line is the default.

=head3 Seperate code entries

Each B<code> entry (whether a string or before/step/after hash) should have
control of the lines it writes to with B<mark>.  This means that the B<lines>
entries must also be distinct.

It is OK for many different B<code> entries to read from the same B<line>.  But
only one B<code> entry must write to each line.

=head1 OPTIONS

=head3 function

If used, it must be C<mark>.  However, this is the default so you won't often
see it.

=head3 first_only

Setting this to 1 ensures that only the first mark of this block is shown,
rather than a mark for every date that passes the test.  A value of 0 means all
appropriate values are marked.

This module is only ever invoked from a code fragment within a model B<test>.
See L<Finance::Shares::Code/Marking the Chart>.  Typically the code fragment
will test the data with some condition such as the following.

    mark($mymark, $close) if $line1 > $line2;

Here the B<mark> module code is only visited for those dates where the value of
$line1 is above $line2.  Typically these would be entries in the model B<lines>
specification, which would include:

    lines => [
	line1 => {
	    ...
	},
	line2 => {
	    ...
	},
	mymark => {
	    function => 'mark',
	    ...
	},
    ],

Imagine a sample with the following data.

    date	    line1   line2   comp
    2003-07-08	    47	    49	    
    2003-07-09	    51	    50	    >
    2003-07-10	    55	    51	    >
    2003-07-11	    53	    52	    >
    2003-07-14	    49	    52
    2003-07-15	    48	    51
    2003-07-16	    51	    50	    >
    2003-07-17	    56	    51	    >

With B<first_only> set to 0, there would be five marks.  But if B<first_only>
was 1, there would be only two - on 2003-07-09 and 2003-07-16.

=over

[Undefined values can confuse this feature.  To be on the safe side
either only use data selected by C<quotes> or be sure to let B<mark()> see the
undefined dates:
    
    mark($mymark, $close) if ($line1 > $line2)
	or (not defined $line1) 
	or (not defined $line2);

B<mark()> assumes that dates missed are failures, and will normally show
a 'first' marker after a gap.  But the gap might be just undefined data and not
a series of dates that failed. B<mark()> adjusts for any undefined values it
sees, but cannot make allowances for undefined values if it is never called for
them.]

=back

=head3 graph

If present, this should be a tag declared as a C<charts> resource.  It
identifies a particular graph within a chart page.  A B<gtype> is implied.  (No
default)

=head3 gtype

Required, unless B<graph> is given.  This specifies the type of graph the function
lines should appear on.  It should be one of C<price>, C<volume>, C<analysis> or
C<logic>.  (Default: C<price>)

=head3 line

Identifies the line(s) whose data is used by the code writing to this line.

=head3 out

If you wish, you may declare the output line names here.

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

There are three special settings, identified by strings C<circle>, C<up_arrow>
and C<down_arrow>.  They are all affected by the B<size> option.  For example,

    style => 'up_arrow',
    size  => 12,

is equivalent to:

    style => {
	bgnd_outline => 0,
	point => {
	    shape    => 'up_arrow',
	    size     => 12,
	    width    => 2,
	    y_offset => -12,
	},
    },

    
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
L<Finance::Shares::Function> and L<Finance::Shares::Line>.
Also, L<Finance::Shares::Code> covers writing your own tests.

=cut

