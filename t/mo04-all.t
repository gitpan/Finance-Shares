#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 2;
use TestFuncs qw(check_filesize show_lines);
use PostScript::File          1.00 qw(check_file);
use PostScript::Graph::Style  1.00;
use Finance::Shares::Model    0.12;

my $name = 't/mo04-all';

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

### Model
my $fsm = new Finance::Shares::Model(
    verbose => 1,

    ## sources
    sources => [
	'01-shell' => 't/01-shell.csv',
	'02-boc'   => 't/02-boc.csv',
	'03-boc'   => 't/03-boc.csv',
	'04-arm'   => 't/04-arm.csv',
	'05-boc'   => 't/05-boc.csv',
	'06-egg'   => 't/06-egg.csv',
	'07-ulvr'  => 't/07-ulvr.csv',
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
	    percent => 0,
	},
	tests => {
	    percent => 0,
	},
    },
    
    ## samples
    samples => [
	1 => { source => '01-shell', symbol => 'SHEL.L', dates_by => 'weekdays', },
	2 => { source => '02-boc',   symbol => 'BOC.L',  dates_by => 'quotes',   },
	3 => { source => '03-boc',   symbol => 'BOC.L',  dates_by => 'days',     },
	4 => { source => '04-arm',   symbol => 'ARM.L',  dates_by => 'weeks',    },
	5 => { source => '05-boc',   symbol => 'BOC.L',  dates_by => 'weekdays', },
	6 => { source => '06-egg',   symbol => 'EGG.L',  dates_by => 'months',   },
	7 => { source => '07-ulvr',  symbol => 'ULVR.L', dates_by => 'weekdays', },
    ],
);
ok(1, 'model built');

### Finish
$fsm->output($name);
my $psfile = check_file("$name.ps");
ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# does the chart looks different?
warn "\nUse ghostview or similar to inspect results file:\n$psfile\n";


