#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 8;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::exponential_average;

my $filename = 't/122';
my $csvfile  = 't/shire.csv';
my $sample   = 'default';
my $stock    = 'SHP.L';
my $date     = 'default';

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,

    sources => $csvfile,
    dates => {
	by    => 'weekdays',
	before => 0,
    },
    charts => [
    ],
    lines => [
	one => { 
	    function => 'exponential_average',
	    graph    => 'price',
	    line     => 'close',
	    period   => 5,
	},
	two => { 
	    function => 'exponential_average',
	    graph    => 'price',
	    line     => 'close',
	    period   => 20,
	},
	three => { 
	    function => 'exponential_average',
	    graph    => 'volume',
	    line     => 'volume',
	    period   => 10,
	},
    ],
    sample => {
	stock => $stock,
	lines => [qw(one two three)],
    },
);

my ($nlines, $npages, @files) = $fsm->build();
is($nlines, 3, 'Number of lines');

my $dump = 0;
my $page = "$sample/$stock/$date";
my $line = $fsm->{pfsls}[0][0][0];
my $np   = $line->{npoints};
is($line->name, "$page/one/expo", 'line 1 name');
is($np, 56, 'line 1 points');
line_dump($line->{data}, "$filename.data") if $dump;
ok(line_compare($line->{data}, "$filename.data"), 'line 1 data');

$line = $fsm->{pfsls}[0][1][0];
$np   = $line->{npoints};
is($line->name, "$page/two/expo", 'line 2 name');
is($np, 41, 'line 2 points');

$line = $fsm->{pfsls}[0][2][0];
$np   = $line->{npoints};
is($line->name, "$page/three/expo", 'line 3 name');
is($np, 51, 'line 3 points');

