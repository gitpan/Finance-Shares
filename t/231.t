#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 10;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::oversold;
use Finance::Shares::undersold;

# testing oversold

my $filename = 't/231';
my $csvfile  = 't/shire.csv';
my $sample   = 'default';
my $stock    = 'SHP.L';
my $date     = 'default';

add_show_objects(
    'Finance::Shares::Line',
    'Finance::Shares::oversold',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,
    show_values => 1,

    sources => $csvfile,
    dates => {
	by    => 'weekdays',
	before => 0,
    },
    chart => {
	x_axis => {
	    show_lines => 1,
	    mid_width => 0,
	    mid_color => 1,
	},
	graphs => [
	    price => {
		gtype => 'price',
		percent => 70,
		points => {
		    shape => 'candle2',
		    #width => 1.5,
		},
	    },
	    'Oversold gradient' => {
		gtype => 'analysis',
		percent => 30,
		show_dates => 1,
		y_axis => {
		    mid_color   => [1, 1, 0.95],
		    #heavy_color => [0.3, 0.3, 0.75],
		},
	    },
	    volume => {
		gtype => 'volume',
		percent => 0,
	    },
	],
    },
    lines => [
	oversold => {
	    function => 'oversold',
	    gtype    => 'price',
	    min      => 358,
	    max      => 370,
	    acceptable => '60%',
	    #acceptable => 1.0,
	    strict   => 0,
	    period   => 3,
	    gradient => 1,
	},
	undersold => {
	    function => 'undersold',
	    gtype    => 'price',
	    min      => 344,
	    max      => 356,
	    #acceptable => '90%',
	    acceptable => 1,
	    strict   => 0,
	    period   => 3,
	    gradient => 1,
	},
    ],
    sample => {
	stock => $stock,
	line  => ['oversold', 'undersold'],
    },
);


my ($nlines, $npages, @files) = $fsm->build();
#warn $fsm->show_model_lines;
is($nlines, 5, 'Number of lines');

my $dump = 0;
my $line = $fsm->{pfsls}[0][0][0];
my $np = $line->{npoints};
is($np, 57, 'oversold points');
is($line->{key}, "oversold 'SHP.L Closing price' averaged over 3 weekdays (Shape only)", 'oversold key');
line_dump($line->{data}, "$filename.data") if $dump;
ok(line_compare($line->{data}, "$filename.data"), 'rising line');

$line = $fsm->{pfsls}[0][0][1];
$np = $line->{npoints};
is($np, 65, 'oversold boundary points');
is($line->{key}, "boundary for oversold 'SHP.L Closing price'", 'oversold boundary key');

$line = $fsm->{pfsls}[0][1][0];
$np = $line->{npoints};
is($np, 57, 'undersold points');
is($line->{key}, "undersold 'SHP.L Closing price' averaged over 3 weekdays (Shape only)", 'undersold key');

$line = $fsm->{pfsls}[0][1][1];
$np = $line->{npoints};
is($np, 65, 'undersold boundary points');
is($line->{key}, "boundary for undersold 'SHP.L Closing price'", 'undersold boundary key');

