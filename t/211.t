#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 9;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::percent_band;

# testing percent bands

my $filename = 't/211';
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
		gtype   => 'price',
		percent => 70,
		points => {
		    shape => 'close2',
		    width => 2,
		    color => 0,
		},
	    },
	    volume => {
		gtype   => 'volume',
		percent => 30,
	    },
	],
    },
    lines => [
	band3 => {
	    function => 'percent_band',
	    percent  => 3,
	},
	band8 => {
	    function => 'percent_band',
	    percent  => 8,
	},
	band12 => {
	    function => 'percent_band',
	    gtype    => 'volume',
	    line     => 'volume',
	    percent  => 50,
	},
    ],
    sample => {
	stock => $stock,
	line  => ['band3', 'band8', 'band12'],
    },
);


my ($nlines, $npages, @files) = $fsm->build();
is($nlines, 3, 'Number of lines');

#show $fsm, $fsm->{pfsls}, 4;
my $dump = 0;
my $line = $fsm->{pfsls}[0][0][0];
my $np = $line->{npoints};
is($np, 147, '3% band points above');
line_dump($line->{data}, "$filename-hi.data") if $dump;
ok(line_compare($line->{data}, "$filename-hi.data"), 'hi line');

$line = $fsm->{pfsls}[0][0][1];
$np = $line->{npoints};
is($np, 147, '3% band points below');
line_dump($line->{data}, "$filename-lo.data") if $dump;
ok(line_compare($line->{data}, "$filename-lo.data"), 'lo line');

$line = $fsm->{pfsls}[0][1][0];
$np = $line->{npoints};
is($np, 147, '8% band points above');

$line = $fsm->{pfsls}[0][1][1];
$np = $line->{npoints};
is($np, 147, '8% band points below');

$line = $fsm->{pfsls}[0][2][0];
$np = $line->{npoints};
is($np, 147, '12% band points above');

$line = $fsm->{pfsls}[0][2][1];
$np = $line->{npoints};
is($np, 147, '12% band points below');


