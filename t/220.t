#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 10;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::momentum;

# testing momentum

my $filename = 't/220';
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
	    'Price momentum' => {
		gtype => 'analysis',
		percent => 20,
	    },
	    'Prices' => {
		gtype => 'price',
		percent => 20,
		show_dates => 1,
	    },
	    'Volumes' => {
		gtype => 'volume',
		percent => 20,
	    },
	    'Volume momentum' => {
		gtype => 'analysis',
		percent => 20,
	    },
	],
    },
    lines => [
	mom1 => {
	    function => 'momentum',
	    period   => 1,
	},
	mom5 => {
	    function => 'momentum',
	    period   => 5,
	    graph    => 'Prices',
	},
	mom20 => {
	    function => 'momentum',
	    period   => 20,
	},
	mom10 => {
	    function => 'momentum',
	    graph    => 'Volume momentum',
	    line     => 'volume',
	    period   => 10,
	},
    ],
    sample => {
	stock => $stock,
	line  => [qw(mom1 mom5 mom10 mom20)],
    },
);


my ($nlines, $npages, @files) = $fsm->build();
is($nlines, 4, 'Number of lines');

#show $fsm, $fsm->{pfsls}, 4;
my $dump = 0;
my $line = $fsm->{pfsls}[0][0][0];
my $np = $line->{npoints};
is($np, 146, 'mom1 points');
is($line->{key}, "1 weekday momentum of 'LGEN.L Closing price'", 'mom1 key');

$line = $fsm->{pfsls}[0][1][0];
$np = $line->{npoints};
is($np, 142, 'mom5 points');
is($line->{key}, "5 weekday momentum of 'LGEN.L Closing price' (Shape only)", 'mom5 key');
line_dump($line->{data}, "$filename.data") if $dump;
ok(line_compare($line->{data}, "$filename.data"), 'mom1 line');

$line = $fsm->{pfsls}[0][3][0];
$np = $line->{npoints};
is($np, 127, 'mom20 points');
is($line->{key}, "20 weekday momentum of 'LGEN.L Closing price'", 'mom20 key');

$line = $fsm->{pfsls}[0][2][0];
$np = $line->{npoints};
is($line->{key}, "10 weekday momentum of 'LGEN.L Trading volume'", 'mom10 key');
is($np, 137, 'mom10 points');


