#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 3;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);

my $filename = 't/022';

add_show_objects(
    'Finance::Shares::Line',
    'Finance::Shares::mark',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,
    null => 'chuckit',

    code => [
	avg => q(
	    my $total = 0;
	    my $count = 0;
	    foreach my $v (@*/*//close) {
		next unless defined $v;
		$total += $v;
		$count++;
	    }
	    return unless $count;
	    mark('average', $total/$count);
	),
	copy => q(
	    my $v = $working///average;
	    mark('Average of closing prices', $v);
	),
    ],

    chart => {
	graphs => [
	    volume => {
		gtype => 'volume',
		percent => 0,
	    },
	],
    },
    
    groups => [
	supermarkets => {
	    code => [qw(copy)],
	},
	working => {
	    code => [qw(avg)],
	    chart => 'chuckit',
	},
    ],

    samples => [
	working => {
	    stock    => 'chuckit',
	    source   => 'chuckit',
	    group    => 'working',

	},
	morrison => {
	    stock    => 'MRW.L',
	    source   => 't/mrw.csv',
	},
	sainsbury => {
	    stock    => 'SBRY.L',
	    source   => 't/sbry.csv',
	},
	safeway => {
	    stock    => 'SFW.L',
	    source   => 't/sfw.csv',
	},
	tesco => {
	    stock    => 'TSCO.L',
	    source   => 't/tsco.csv',
	},
    ],
);


my ($nlines, $npages, @files) = $fsm->build();
#warn $fsm->show_model_lines;

is($npages, 4, 'Number of pages');
is($nlines, 13, 'Number of lines');

my $line;
my $dump = 0;
$line = $fsm->{ptfsls}[4][1];
line_dump($line->{data}, "$filename.data") if $dump;
ok(line_compare($line->{data}, "$filename.data"), 'average line');


