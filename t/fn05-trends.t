#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use TestFuncs qw(show is_same csv_to_sample check_filesize);
use PostScript::File          1.00 qw(check_file);
use PostScript::Graph::Style  1.00;
use Finance::Shares::Sample   0.12 qw(line_id);
use Finance::Shares::Chart    0.14;
use Finance::Shares::Momentum 0.03;
use Finance::Shares::Averages 0.12;

my $name = 't/fn05-trends';
my $source = 't/05-boc.csv';
plan tests => 8;

### PostScript::File
my $pf = new PostScript::File(
    landscape => 1,
);

### Finance::Shares::Sample
my $fss = new Finance::Shares::Sample(
    source   => $source,
    symbol   => 'BOC.L',
    dates_by => 'days',
);

### PostScript::Graph::Style
my $seq = new PostScript::Graph::Sequence;
$seq->setup('red', [0, 1, 0.5]);
$seq->setup('green', [0, 1, 0.5]);
$seq->setup('blue', [0, 1, 0.5]);
$seq->auto(qw(green blue red));
my $style = {
    sequence => $seq,
    same => 1,
    line => {
	width => 2,
    },
};

### Function lines
my @args = (
    function => 'gradient',
    period => 10,
    style => $style,
    weight => 100,
    #decay => 0.95,
    cutoff => $style,
    gradient => $style,
);

my $smallest = 10;
my $rising = $fss->rising(@args, smallest => $smallest);
ok( $fss->{lines}{tests}{$rising}, "$rising stored" );
my $falling = $fss->falling(@args, smallest => $smallest);
ok( $fss->{lines}{tests}{$falling}, "$falling stored" );
my $oversold = $fss->oversold(@args, sd => 2.00);
ok( $fss->{lines}{tests}{$oversold}, "$oversold stored" );
my $undersold = $fss->undersold(@args, sd => 2.00);
ok( $fss->{lines}{tests}{$undersold}, "$undersold stored" );

### Finance::Shares::Chart
my $background = [1, 1, 0.9];
my $fsc = new Finance::Shares::Chart(
    file => $pf,
    sample => $fss,
    dots_per_inch => 72,
    smallest => 6,
    background => $background,
    x_axis => {
	mid_color => $background,
    },
    prices => {
	percent => 33,
	sequence => $seq,
	points => {
	    shape => 'close',
	    color => [ 0.6, 0.2, 0.2 ],
	    width => 2,
	},
    },
    volumes => {
	percent => 0,
    },
    cycles => {
	percent => 40,
    },
    tests => {
	percent => 30,
	show_dates => 1,
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
is( $count, 14, "$count known lines" );

### finish
$fsc->output($name);
my $psfile = check_file("$name.ps");
ok(-e $psfile, 'PostScript file created');
ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# does the chart looks different?
warn "\nUse ghostview or similar to inspect results file:\n$psfile\n";

