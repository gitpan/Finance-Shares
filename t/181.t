#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 6;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::moving_average;
use Finance::Shares::greater_than;
use Finance::Shares::less_than;

# testing conditioning of levels, greater_than and less_than

my $filename = 't/181';
my $csvfile  = 't/shire.csv';
my $sample   = 'default';
my $stock    = 'SHP.L';
my $date     = 'default';

add_show_objects(
    'Finance::Shares::Line',
    'Finance::Shares::high',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,
    show_values => 1,

    sources => $csvfile,
    dates => {
	start => '2003-04-01',
	end   => '2003-07-03',
	by    => 'weekdays',
	#before => 0,
    },
    charts => [
    ],
    lines => [
	slow => { 
	    function => 'moving_average',
	    graph    => 'price',
	    line     => 'high',
	    period   => 10,
	},
	pgt => {
	    function => 'greater_than',
	    lines    => ['high', 'slow'],
	    graph    => 'price',
	    min      => 1050,
	    max      => 1200,
	    decay    => 0.5,
	},
	vgt => {
	    function => 'less_than',
	    lines    => ['volume', 17000000],
	    ramp     => -15,
	},
    ],
    sample => {
	stock => $stock,
	lines => [qw(pgt vgt)],
    },
);


my ($nlines, $npages, @files) = $fsm->build();
is($nlines, 4, 'Number of lines');

my $dump = 0;
my $pgt = $fsm->{pfsls}[0][0][0];
is($pgt->{lmin}, 1050, 'pgt lmin');
is($pgt->{lmax}, 1200, 'pgt lmax');
is($pgt->{scale}, 1, 'pgt scale');
line_dump($pgt->{data}, "$filename-pgt.data") if $dump;
ok(line_compare($pgt->{data}, "$filename-pgt.data"), 'pgt line');

my $vgt = $fsm->{pfsls}[0][1][0];
line_dump($vgt->{data}, "$filename-vgt.data") if $dump;
ok(line_compare($vgt->{data}, "$filename-vgt.data"), 'vgt line');
