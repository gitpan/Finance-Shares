#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 2;
use TestFuncs qw(check_filesize);
use PostScript::File          1.00 qw(check_file);
use PostScript::Graph::Style  1.00;
use Finance::Shares::Model    0.12;

my $name = 't/mo02-single';

### Setup
use Finance::Shares::Averages 0.12;
use Finance::Shares::Bands    0.13;
use Finance::Shares::Momentum 0.02;

my $data_colour = [0.3, 0.7, 0.7 ];
my $bgnd_colour = [0.95,0.95,1   ];
my $light_blue  = [0,   0.7, 1   ];

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

### Model
my $fsm = new Finance::Shares::Model(
    ## sources
    source => 't/07-ulvr.csv',
    
    ## files
    files => [
	$name => {
	    landscape => 1,
	},
    ],
    
    ## charts
    chart => {
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
	    percent => 0,
	},
	tests => {
	    percent => 40,
	},
    },
    
    ## functions
    functions => [
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
    ],
    
    ## signals
    signals => [
	sell => [ 'mark_sell', { graph => 'prices', line => 'close' } ],
    ],
    
    ## tests
    tests => [
	rising => {
	    graph1 => 'prices', line1 => 'fast',
	    test   => 'le',
	    graph2 => 'prices', line2 => 'medium',
	    graph  => 'tests',
	    style  => $test_style,
	    signal => 'sell',
	},
    ],
    
    ## groups
    group => { 
	functions => [qw(medium fast)],
	tests => [qw(rising)],
    },
    
    ## samples
    sample => {
	symbol => 'ULVR.L',
    },
);
ok(1, 'model built');

### Finish
print $fsm->output($name);
my $psfile = check_file("$name.ps");
ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# does the chart looks different?
warn "\nUse ghostview or similar to inspect results file:\n$psfile\n";

