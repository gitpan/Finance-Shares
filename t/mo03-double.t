#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 2;
use TestFuncs qw(check_filesize show_lines);
use PostScript::File 0.11 qw(check_file);
use PostScript::Graph::Style;
use Finance::Shares::Model;

my $name = 't/mo03-double';

### Setup
use Finance::Shares::Averages;
use Finance::Shares::Bands;
use Finance::Shares::Momentum;

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

my $boll_style = new PostScript::Graph::Style( $fn_style );
my $env_style = new PostScript::Graph::Style( $fn_style );

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
    sources => [
	ulvr => 't/07-ulvr.csv',
    ],
    
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
	    percent => 30,
	    points => {
		color => $data_colour,
		width => 1.5,
	    },
	},
	volumes => {
	    percent => 30,
	    bars => {
		color => $data_colour,
	    },
	},
	cycles => {
	    percent => 40,
	},
    },
    
    ## functions
    functions => [
	grad => {
	    function => 'gradient',
	    style => $fn_style,
	},
	chnl => {
	    function => 'channel',
	    graph => 'volumes',
	    line => 'volume',
	    period => 10,
	    style => $fn_style,
	},
	envl => {
	    function => 'envelope',
	    percent => 4,
	    style => $env_style,
	},
	boll => {
	    function => 'bollinger_band',
	    graph => 'cycles',
	    line => 'grad',
	    style => $boll_style,
	    shown => 1,
	},
    ],
    
    ## signals
    signals => [
	env_mark => [ 'mark_sell', { graph => 'prices', line => 'high', key => 'above band' } ],
	vol_mark => [ 'mark', { graph => 'volumes', line => 'chnl_high', key => '10 day high' } ],
    ],
    
    ## tests
    tests => [
	envelope => {
	    graph1 => 'prices', line1 => 'high',
	    test   => 'ge',
	    graph2 => 'prices', line2 => 'envl_high',
	    signal => 'env_mark',
	    shown  => 0,
	},
	channel => {
	    graph1 => 'volumes', line1 => 'volume',
	    test   => 'ge',
	    graph2 => 'volumes', line2 => 'chnl_high',
	    graph  => 'volumes',
	    signal => 'vol_mark',
	    shown  => 0,
	},
    ],
    
    ## groups
    group => { 
	functions => [qw(grad boll chnl envl)],
	tests => [qw(envelope channel)],
    },
    
    ## samples
    sample => {
	symbol => 'ULVR.L',
    },
);
ok(1, 'model built');

### Finish
$fsm->output($name);
my $psfile = check_file("$name.ps");
ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# does the chart looks different?
warn "\nUse ghostview or similar to inspect results file:\n$psfile\n";


