#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 7;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::highest;
use Finance::Shares::lowest;
use Finance::Shares::greater_equal;
use Finance::Shares::less_equal;

# testing highest, lowest, greater_equal, less_equal

my $filename = 't/180';
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

    sources => $csvfile,
    dates => {
	start => '2003-04-01',
	end   => '2003-07-03',
	by    => 'weekdays',
	after => 10,
	before => 0,
    },
    charts => [
    ],
    lines => [
	phi => { 
	    function => 'highest',
	    graph    => 'price',
	    line     => 'high',
	    period   => 10,
	},
	plo => { 
	    function => 'lowest',
	    graph    => 'price',
	    line     => 'low',
	    period   => 10,
	},
	vhi => { 
	    function => 'highest',
	    graph    => 'volume',
	    line     => 'volume',
	    period   => 5,
	},
	vlo => { 
	    function => 'lowest',
	    graph    => 'volume',
	    line     => 'volume',
	    period   => 5,
	},
	vge => {
	    function => 'greater_equal',
	    lines    => ['volume', 'vhi'],
	    max      => 95,
	    min      => 55,
	},
	vle => {
	    function => 'less_equal',
	    lines    => ['volume', 'vlo'],
	    max      => 45,
	    min      => 5,
	},
    ],
    sample => {
	stock => $stock,
	lines => [qw(phi plo vhi vlo vge vle)],
    },
);


my ($nlines, $npages, @files) = $fsm->build();
is($nlines, 6, 'Number of lines');

my $dump = 0;
my $phi = $fsm->{pfsls}[0][0][0];
line_dump($phi->{data}, "$filename-phi.data") if $dump;
ok(line_compare($phi->{data}, "$filename-phi.data"), 'phi line');

my $plo = $fsm->{pfsls}[0][1][0];
line_dump($plo->{data}, "$filename-plo.data") if $dump;
ok(line_compare($plo->{data}, "$filename-plo.data"), 'plo line');

my $vhi = $fsm->{pfsls}[0][2][0];
line_dump($vhi->{data}, "$filename-vhi.data") if $dump;
ok(line_compare($vhi->{data}, "$filename-vhi.data"), 'vhi line');

my $vlo = $fsm->{pfsls}[0][3][0];
line_dump($vlo->{data}, "$filename-vlo.data") if $dump;
ok(line_compare($vlo->{data}, "$filename-vlo.data"), 'vlo line');

my $vge = $fsm->{pfsls}[0][4][0];
line_dump($vge->{data}, "$filename-vge.data") if $dump;
ok(line_compare($vge->{data}, "$filename-vge.data"), 'vge line');

my $vle = $fsm->{pfsls}[0][5][0];
line_dump($vle->{data}, "$filename-vle.data") if $dump;
ok(line_compare($vle->{data}, "$filename-vle.data"), 'vle line');

