#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 4;
use TestFuncs qw(show is_same csv_to_sample check_filesize);
use PostScript::File          1.00 qw(check_file);
use PostScript::Graph::Style  1.00;
use Finance::Shares::Sample   0.12 qw(line_id);
use Finance::Shares::Chart    0.14;
use Finance::Shares::Momentum 0.03;
use Finance::Shares::Averages 0.12;

my $name = 't/mm03-direction';
my $source = 't/04-arm.csv';

### PostScript::File
my $pf = new PostScript::File(
    landscape => 1,
);

### Finance::Shares::Sample
my $fss = new Finance::Shares::Sample(
    source   => $source,
    symbol   => 'ARM.L',
    dates_by => 'weekdays',
);

### PostScript::Graph::Style
my $seq = new PostScript::Graph::Sequence;
$seq->setup('red', [1, 0, 0.5]);
$seq->setup('green', [0, 1, 0.5]);
$seq->setup('blue', [0, 1, 0.5]);
$seq->auto(qw(green blue red));
my $style = {
    sequence => $seq,
    line => {
	width => 2,
	outer_color => [0.5, 0.5, 0.5],
    },
};

### Function lines
#my $up = $fss->direction(
#    dir    => 1,
#    period => 0,
#    style  => $style,
#    shown  => 1,
#    strict => 1,
#    scaled => 1,
#);

my $up5 = $fss->direction(
    dir    => 1,
    period => 10,
    style  => $style,
    shown  => 1,
    strict => 1,
#    scaled => 1,
);

my $down = $fss->direction(
    dir    => -1,
    period => 0,
    style  => $style,
    shown  => 1,
    strict => 1,
#    scaled => 1,
);

#my $down5 = $fss->direction(
#    dir    => -1,
#    period => 5,
#    style  => $style,
#    shown  => 1,
#    strict => 1,
#    scaled => 1,
#);

#my $avg = $fss->direction(
#    dir    => 0,
#    period => 0,
#    style  => $style,
#    shown  => 1,
#    strict => 1,
#    scaled => 1,
#);

my $avg5 = $fss->direction(
    dir    => 0,
    period => 5,
    style  => $style,
    shown  => 1,
    strict => 1,
#    scaled => 1,
);

### Finance::Shares::Chart
my $background = [1, 1, 0.9];
my $fsc = new Finance::Shares::Chart(
    file => $pf,
    sample => $fss,
    dots_per_inch => 72,
    smallest => 6,
    background => $background,
    bgnd_outline => 1,
    x_axis => {
	mid_color => $background,
    },
    prices => {
	percent => 25,
	sequence => $seq,
	points => {
	    shape => 'stock2',
	    color => [ 0.6, 0.2, 0.2 ],
	    width => 2,
	},
    },
    volumes => {
	percent => 0,
    },
    cycles => {
	percent => 25,
    },
);
ok($fsc, 'Finance::Shares::Chart created');

### output
$fsc->build_chart();

my $count = 0;
print "Known lines...\n";
foreach my $g (qw(prices volumes cycles tests)) {
    foreach my $lineid ( $fss->known_lines($g) ) {
	print "  $g : $lineid\n";
	$count++;
    };
}
is( $count, 9, "$count known lines" );

### finish
$fsc->output($name);
my $psfile = check_file("$name.ps");
ok(-e $psfile, 'PostScript file created');
ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# does the chart looks different?
warn "\nUse ghostview or similar to inspect results file:\n$psfile\n";

