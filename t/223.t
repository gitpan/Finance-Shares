#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 10;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::rate_of_change;
use Finance::Shares::momentum;
use Finance::Shares::gradient;

# testing gradient

my $filename = 't/223';
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
	    'Prices' => {
		gtype => 'price',
		percent => 20,
		show_dates => 1,
		points => {
		    shape => 'close',
		    width => 2,
		},
	    },
	    '1 day comparison' => {
		gtype => 'level',
		percent => 40,
	    },
	    '5 day comparison' => {
		gtype => 'level',
		percent => 40,
	    },
	    'volume' => {
		gtype => 'volume',
		percent => 0,
	    },
#	    'Gradient' => {
#		gtype => 'analysis',
#		percent => 20,
#	    },
#	    'Momentum' => {
#		gtype => 'analysis',
#		percent => 20,
#	    },
#	    'Rate of change' => {
#		gtype => 'analysis',
#		percent => 20,
#	    },
	],
    },
    lines => [
	mom1 => {
	    function => 'momentum',
	    period   => 1,
	    graph    => '1 day comparison',
	    min      => 0,
	    max      => 33,
	},
	grad1 => {
	    function => 'gradient',
	    period   => 1,
	    graph    => '1 day comparison',
	    min      => 34,
	    max      => 66,
	},
	roc1 => {
	    function => 'rate_of_change',
	    period   => 1,
	    graph    => '1 day comparison',
	    min      => 67,
	    max      => 100,
	},
	mom5 => {
	    function => 'momentum',
	    period   => 5,
	    graph    => '5 day comparison',
	    min      => 0,
	    max      => 33,
	},
	grad5 => {
	    function => 'gradient',
	    period   => 5,
	    graph    => '5 day comparison',
	    min      => 34,
	    max      => 66,
	},
	roc5 => {
	    function => 'rate_of_change',
	    period   => 5,
	    graph    => '5 day comparison',
	    min      => 67,
	    max      => 100,
	},
    ],
    sample => {
	stock => $stock,
	line  => [qw(mom1 grad1 roc1 mom5 grad5 roc5)],
    },
);


my ($nlines, $npages, @files) = $fsm->build();
is($nlines, 6, 'Number of lines');

#show $fsm, $fsm->{pfsls}, 4;
my $dump = 0;
my $line = $fsm->{pfsls}[0][5][0];
my $np = $line->{npoints};
is($np, 142, 'roc5 points');
is($line->{key}, "5 weekday rate of change of 'LGEN.L Closing price' (Shape only)", 'roc5 key');
line_dump($line->{data}, "$filename-roc.data") if $dump;
ok(line_compare($line->{data}, "$filename-roc.data"), 'roc5 line');

$line = $fsm->{pfsls}[0][4][0];
$np = $line->{npoints};
is($np, 142, 'grad5 points');
is($line->{key}, "5 weekday gradient of 'LGEN.L Closing price' (Shape only)", 'grad5 key');
line_dump($line->{data}, "$filename-grad.data") if $dump;
ok(line_compare($line->{data}, "$filename-grad.data"), 'roc5 line');

$line = $fsm->{pfsls}[0][3][0];
$np = $line->{npoints};
is($np, 142, 'mom5 points');
is($line->{key}, "5 weekday momentum of 'LGEN.L Closing price' (Shape only)", 'mom5 key');
line_dump($line->{data}, "$filename-mom.data") if $dump;
ok(line_compare($line->{data}, "$filename-mom.data"), 'mom5 line');

