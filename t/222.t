#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 10;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::rate_of_change;

# testing gradient

my $filename = 't/222';
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
	    'Price gradient' => {
		gtype => 'analysis',
		percent => 20,
	    },
	    'Prices' => {
		gtype => 'price',
		percent => 40,
		show_dates => 1,
		points => {
		    shape => 'close',
		    width => 2,
		},
	    },
	    'Volumes' => {
		gtype => 'volume',
		percent => 20,
	    },
	    'Volume gradient' => {
		gtype => 'analysis',
		percent => 20,
	    },
	],
    },
    lines => [
	grad1 => {
	    function => 'rate_of_change',
	    period   => 1,
	},
	grad5 => {
	    function => 'rate_of_change',
	    period   => 5,
	    graph    => 'Prices',
	},
	grad20 => {
	    function => 'rate_of_change',
	    period   => 20,
	},
	grad10 => {
	    function => 'rate_of_change',
	    graph    => 'Volume gradient',
	    line     => 'volume',
	    period   => 10,
	},
    ],
    sample => {
	stock => $stock,
	line  => [qw(grad1 grad5 grad10 grad20)],
    },
);


my ($nlines, $npages, @files) = $fsm->build();
is($nlines, 4, 'Number of lines');

#show $fsm, $fsm->{pfsls}, 4;
my $dump = 0;
my $line = $fsm->{pfsls}[0][0][0];
my $np = $line->{npoints};
is($np, 146, 'roc1 points');
is($line->{key}, "1 weekday rate of change of 'LGEN.L Closing price'", 'roc1 key');

$line = $fsm->{pfsls}[0][1][0];
$np = $line->{npoints};
is($np, 142, 'roc5 points');
is($line->{key}, "5 weekday rate of change of 'LGEN.L Closing price' (Shape only)", 'roc5 key');
line_dump($line->{data}, "$filename.data") if $dump;
ok(line_compare($line->{data}, "$filename.data"), 'roc5 line');

$line = $fsm->{pfsls}[0][3][0];
$np = $line->{npoints};
is($np, 127, 'roc20 points');
is($line->{key}, "20 weekday rate of change of 'LGEN.L Closing price'", 'roc20 key');

$line = $fsm->{pfsls}[0][2][0];
$np = $line->{npoints};
is($line->{key}, "10 weekday rate of change of 'LGEN.L Trading volume'", 'roc10 key');
is($np, 137, 'roc10 points');


