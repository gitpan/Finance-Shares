#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use TestFuncs qw(show show_lines csv_to_sample check_filesize);
use PostScript::File          1.00 qw(check_file);
use Finance::Shares::Sample   0.12 qw(line_id);
use Finance::Shares::Chart    0.14;
use Finance::Shares::Averages 0.12;
use Finance::Shares::Model    0.12;

my $name = 't/te01-above';
my $source = 't/01-shell.csv';
my $test = {};	    # 0 to stop, {} to collect Chart test data
plan tests => 7;
my $csv = csv_to_sample($source);
my $ndates = keys %{$csv->{close}};

### PostScript::File
my $pf = new PostScript::File(
    landscape => 1,
);

### Finance::Shares::Sample
my $fss = new Finance::Shares::Sample(
    source => $source,
    symbol => 'SHEL.L',
    dates_by => 'weekdays',
);
is( $fss->start_date,'2002-06-27', 'start date correct' );
is( $fss->end_date,'2002-09-05', 'end date correct' );

### PostScript::Graph::Style
my $seq = new PostScript::Graph::Sequence;
my $green = {
    same => 0,
    line => {
	width => 2,
	color => [0.5,1,0.2],
    },
};

### Function lines
$fss->simple_average(period => 3);
my $simple_3 = line_id('simple', 3, 'close');
ok( $fss->{lines}{prices}{$simple_3}, "$simple_3 stored" );
$fss->simple_average(period => 20);
my $simple_20 = line_id('simple', 20, 'close');
ok( $fss->{lines}{prices}{$simple_20}, "$simple_20 stored" );

### Finance::Shares::Model
my $fsm = new Finance::Shares::Model;
$fsm->add_sample($fss);
is( values %{$fsm->{samples}}, 1, '1 Sample stored');

### Test lines
my $id = '3 above 20'; #line_id('above', 'prices', $simple_3, 'prices', $simple_20);
$fsm->test( graph1 => 'prices', line1 => $simple_3,
	    graph2 => 'prices', line2 => $simple_20,
	    test => 'gt', weight => 100,
	    decay => 1.890, ramp => -90, 
	    graph => 'tests', line => $id, key => $id,
	    style => $green, shown => 1, );
ok( $fss->{lines}{tests}{$id}, "$id stored" );
#is( values %{$fss->{lines}{tests}{$id}{data}}, $ndates, "$ndates points in $id" );

### Finance::Shares::Chart
my $fsc = new Finance::Shares::Chart(
    file => $pf,
    sample => $fss,
    test => $test,
    dots_per_inch => 72,
    smallest => 6,
    background => [1, 1, 0.9],
    glyph_ratio => 0.45,
    prices => {
	percent => 67,
	sequence => $seq,
	points => {
	    shape => 'stock',
	    color => [ 1, 0.5, 0.5 ],
	    width => 2,
	},
    },
    volumes => {
	percent => 33,
	bars => {
	    color => [ 0, 0.3, 0 ],
	    outer_width => 1,
	},
    },
);

### finish
$fsc->build_chart();
$fsc->output($name);
my $psfile = check_file("$name.ps");

ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# does the chart looks different?
warn "\nUse ghostview or similar to inspect results file:\n$psfile\n";

print "\nKnown lines...\n";
foreach my $g (qw(prices volumes cycles tests)) {
    foreach my $lineid ( $fss->known_lines($g) ) {
	print "$g : $lineid\n";
    };
}


