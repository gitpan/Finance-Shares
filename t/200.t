#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 3;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::historical_highs;
use Finance::Shares::historical_lows;

# testing historical highs/lows

my $filename = 't/200';
my $csvfile  = 't/lgen.csv';
my $sample   = 'default';
my $stock    = 'LGEN.L';
my $date     = 'default';

add_show_objects(
    'Finance::Shares::Line',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,
    show_values => 1,

    sources => $csvfile,
    dates => {
	start => '2002-06-05',
	end   => '2002-12-31',
	by    => 'quotes',
    },
    chart => {
	x_axis => {
	    show_lines => 1,
	    mid_width => 0,
	    mid_color => 1,
	},
	graphs => [
	    price => {
		gtype   => 'price',
		percent => 50,
		points => {
		    shape => 'close2',
		    width => 2,
		    color => 0,
		},
	    },
	    level => {
		gtype   => 'level',
		percent => 50,
	    },
	    volume => {
		gtype   => 'volume',
		percent => 0,
	    },
	],
    },
    lines => [
	highs => {
	    function => 'historical_highs',
	    line     => 'close',
	    smallest => 9,
	    style    => {
		point => {
		    shape => 'square',
		    size  => 4,
		    color => [0, 0, 1],
		    outer_width => 2,
		},
	    },
	},
	lows => {
	    function => 'historical_lows',
	    line     => 'close',
	    smallest => 9,
	    style    => {
		point => {
		    shape => 'square',
		    size  => 4,
		    color => [1, 0, 0],
		    outer_width => 2,
		},
	    },
	},
    ],
    sample => {
	stock => $stock,
	line  => ['lows', 'highs'],
    },
);


my ($nlines, $npages, @files) = $fsm->build();
is($nlines, 2, 'Number of lines');

#show $fsm, $fsm->{pfsls}, 4;
my $mark_np = $fsm->{pfsls}[0][0][0]{npoints};
is($mark_np, 17, 'Number of points');
$mark_np = $fsm->{pfsls}[0][1][0]{npoints};
is($mark_np, 18, 'Number of points');

