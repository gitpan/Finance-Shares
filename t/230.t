#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 6;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::is_rising;
use Finance::Shares::is_falling;
use Finance::Shares::exponential_average;

# testing is_rising

my $filename = 't/230';
my $csvfile  = 't/shire.csv';
my $sample   = 'default';
my $stock    = 'SHP.L';
my $date     = 'default';

add_show_objects(
    'Finance::Shares::Line',
    'Finance::Shares::rising',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,
    #show_values => 1,

    sources => $csvfile,
    chart => {
	x_axis => {
	    show_lines => 1,
	    mid_width => 0,
	    mid_color => 1,
	},
	graphs => [
	    price => {
		gtype => 'price',
		percent => 25,
	    },
	    volume => {
		gtype => 'volume',
		percent => 0,
	    },
#	    falling => {
#		gtype => 'level',
#		percent => 25,
#	    },
#	    rising => {
#		gtype => 'level',
#		percent => 25,
#	    },
	],
    },
    lines => [
	rising => {
	    function => 'is_rising',
	    #graph    => 'analysis',
	    strict   => 1,
	    period   => 5,
	    gradient => { bar => {} },
	},
	average => {
	    function => 'exponential_average',
	    period   => 10,
	    order    => -1,
	},
	falling => {
	    function => 'is_falling',
	    graph    => 'price',
	    line     => 'average',
	},
    ],
    sample => {
	stock => $stock,
	line  => ['rising', 'falling'],
    },
);


my ($nlines, $npages, @files) = $fsm->build();
is($nlines, 5, 'Number of lines');

#show $fsm, $fsm->{pfsls}, 4;
my $dump = 1;
my $line = $fsm->{pfsls}[0][0][0];
my $np = $line->{npoints};
is($np, 47, 'rising points');
is($line->{key}, "rising 'Closing price' averaged over 5 weekdays (Shape only)", 'rising key');
line_dump($line->{data}, "$filename.data") if $dump;
ok(line_compare($line->{data}, "$filename.data"), 'rising line');

$line = $fsm->{pfsls}[0][1][0];
$np = $line->{npoints};
is($np, 46, 'falling points');
is($line->{key}, "falling '10 weekday exponential average of 'SHP.L Closing price'' (Shape only)", 'falling key');
