#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 4;
use TestFuncs qw(check_filesize);
use PostScript::File 0.11 qw(check_file);
use PostScript::Graph::Style;
use Finance::Shares::Model;

my $name = 't/mo01-multi';

### Setup
use Finance::Shares::Averages;
use Finance::Shares::Bands;
use Finance::Shares::Momentum;

my $data_colour = [0.3, 0.7, 0.7 ];
my $bgnd_colour = [0.95,0.95,1   ];
my $orange      = [0.8, 0.7, 0.4 ];

my $seq1 = new PostScript::Graph::Sequence;
$seq1->setup('color', [[0.5,0,0], [1,0,0], [1,1,0], [0.5,0.5,0], [0,1,0], [0,0.5,0], [0,0.5,0.5], [0,0,1], [0.5,0,0.5]]);
$seq1->auto(qw(color));

### Styles
my $fn_style = {
    sequence => $seq1,
    line => {
	width => 1.5,
	outer_color => 0.4,
    },
};

my $test_style = {
    sequence => $seq1,
    same => 1,
    line => {
	width => 3,
	dashes => [ 1, 2 ],
    },
};

my $file1 = "$name-1";
my $file2 = "$name-2";
my $file3 = "$name-3";

### Model
my $fsm = new Finance::Shares::Model(
    verbose => 3,

    ## sources
    sources => [
	db   => {
	    user => 'test',
	    password => 'test',
	    database => 'test',
	    mode => 'offline',
	},
	ulvr => 't/07-ulvr.csv',
	boc  => 't/05-boc.csv',
    ],
    
    ## files
    files => [
	$file1 => {
	    landscape => 1,
	    title => $file1,
	},
	$file2 => {
	    landscape => 1,
	    title => $file2,
	},
	$file3 => {
	    landscape => 1,
	    title => $file3,
	},
    ],
    
    ## charts
    charts => [
	plain => {
	    prices => {
		percent => 60,
	    },
	    volumes => {
		percent => 40,
		bars => {
		    color => $orange,
		},
	    },
	},
	default => {
	    dots_per_inch => 75,
	    background => $bgnd_colour,
	    invert => 1,
	    x_axis => {
		mid_width => 0,
		mid_color => $bgnd_colour,
	    },
	    key => {
		background => $bgnd_colour,
	    },
	    prices => {
		percent => 60,
		points => {
		    color => $data_colour,
		    width => 1.5,
		},
	    },
	    volumes => {
		percent => 40,
		bars => {
		    color => $data_colour,
		    width => 1,
		},
	    },
	    signals => {
		percent => 30,
	    },
	},
    ],
    
    ## functions
    functions => [
	slow => {
	    function => 'simple_average',
	    period => 21,
	    style => $fn_style,
	},
	medium => {
	    function => 'simple_average',
	    period => 10,
	    style => $fn_style,
	},
	fast => {
	    function => 'simple_average',
	    period => 3,
	    style => $fn_style,
	},
	avg_vol => {
	    function => 'exponential_average',
	    graph => 'volumes',
	    line => 'volume',
	    period => 21,
	    strict => 1,
	    style => $fn_style,
	},
    ],
    
    ## signals
    signals => [
	dummy => [ 'print_values', { message => 'Hello world' } ],
	buy   => [ 'mark_buy',     { graph => 'prices', line => 'close' } ],
    ],
    
    ## tests
    tests => [
	high_vol => {
	    graph1 => 'volumes', line1 => 'volume',
	    test   => 'ge',
	    graph2 => 'volumes', line2 => 'avg_vol',
	    graph  => 'volumes',
	    style  => $test_style,
	    key    => 'high volume',
	},
	rising => {
	    graph1 => 'prices', line1 => 'fast',
	    test   => 'gt',
	    graph2 => 'prices', line2 => 'medium',
	    graph  => 'signals',
	    style  => $test_style,
	    signal => [qw(dummy buy)],
	    key    => 'rising',
	},
    ],
    
    ## groups
    groups => [
	dates => {
	    start_date => '2002-01-01',
	    end_date   => '2002-04-01',
	},
	volume => {
	    functions => [qw(avg_vol)],
	    tests     => [qw(high_vol)],
	},
	price => {
	    functions => [qw(slow medium fast)],
	    tests => [qw(rising)],
	},
	chart1 => {
	    file      => $file1,
	    chart     => 'default',
	},
	chart2 => {
	    file      => $file1,
	    chart     => 'plain',
	},
    ],
    
    ## samples
    samples => [
	ulvr_days => {
	    source => 'ulvr', symbol => 'ULVR.L', dates_by => 'days', page => 'd-ulvr',
	    groups => [qw(price chart1)],
	},
	ulvr_weeks => {
	    source => 'ulvr', symbol => 'ULVR.L', dates_by => 'weeks', page => 'w-ulvr',
	    functions => [qw(slow medium fast)],
	    tests => [qw(rising)],
	},
	boc_days => {
	    source => 'boc', symbol => 'BOC.L', dates_by => 'days', page => 'd-boc',
	    file   => $file3,
	    groups => [qw(dates volume chart2)],
	},
    ],
);
ok(1, 'model built');

### Finish
print $fsm->output($name);
my $psfile = check_file("$file1.ps");
ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# does the chart looks different?
warn "\nUse ghostview or similar to inspect results file:\n$psfile\n";
$psfile = check_file("$file2.ps");
ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# does the chart looks different?
$psfile = check_file("$file3.ps");
ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# does the chart looks different?
warn "\nUse ghostview or similar to inspect results file:\n$psfile\n";

