#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 3;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::on_balance_volume;

# testing on_balance_volume

my $filename = 't/232';
my $csvfile  = 't/mrw.csv';
my $sample   = 'default';
my $stock    = 'MRW.L';
my $date     = 'default';

add_show_objects(
    'Finance::Shares::Line',
    'Finance::Shares::on_balance_volume',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,
    show_values => 1,

    sources => $csvfile,
    dates => {
	before => 0,
    },
    chart => {
	x_axis => {
	    show_lines => 1,
	    mid_width => 0,
	    mid_color => 1,
	},
    },
    lines => [
	obv => {
	    function => 'on_balance_volume',
	},
    ],
    sample => {
	stock => $stock,
	line  => 'obv',
    },
);


my ($nlines, $npages, @files) = $fsm->build();
is($nlines, 2, 'Number of lines');

#show $fsm, $fsm->{pfsls}, 4;
my $dump = 0;
my $line = $fsm->{pfsls}[0][0][0];
my $np = $line->{npoints};
is($np, 38, 'obv points');
line_dump($line->{data}, "$filename.data") if $dump;
ok(line_compare($line->{data}, "$filename.data"), 'obv line');

