#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use TestFuncs qw(show is_same csv_to_sample check_filesize);
use PostScript::File        1.00 qw(check_file);
use Finance::Shares::Sample 0.12;
use Finance::Shares::Chart  0.14;

my $name = 't/ch02-lines';
my $source = 't/02-boc.csv';
my $test = {};	    # 0 to stop, {} to collect Chart test data
plan tests => ($test ? 21 : 18);

### PostScript::File
my $pf = new PostScript::File(
    landscape => 1,
    debug => 2,
    left => 100,
    clipping => 1,
    clip_command => 'stroke',
);
ok($pf, 'PostScript::File created');

### Finance::Shares::Sample
my $fss = new Finance::Shares::Sample(
    source => "$source",
    symbol => 'BOC.L',
    dates_by => 'weekdays',
);
ok( $fss, 'Finance::Shares::Sample created' );
is( $fss->start_date,'2002-01-02', 'start date' );
is( $fss->end_date,'2002-04-30', 'end date' );

my $csv = csv_to_sample("$source");

my $ndates = keys %{$fss->{close}};
is( $ndates, keys %{$csv->{close}}, "$ndates dates" );

### Styles
my $offset = {
    point => {
	shape	 => 'north',
	size	 => 8,
	x_offset => 0,
	y_offset => -8,
	color	 => [0,0,1],
    },
    line => {
    },
};

### Function lines
my $line1 = { '2002-01-11' => 950, '2002-02-06' => 900, '2002-03-28' => 1000, };
my $line2 = { '2002-01-11' => 900, '2002-02-06' => 850, '2002-03-28' => 950, '2002-04-24' => 900, };
my $line3 = { '2002-01-11' => 5000000, '2002-02-06' => 8500000, '2002-03-28' => 13500000, '2002-04-24' => 9000000, };
my $line4 = { '2002-01-11' => 0, '2002-02-06' => 100, '2002-03-28' => -100, '2002-04-24' => 0, };
my $line5 = { '2002-01-11' => 0, '2002-02-06' => 99, '2002-03-28' => 99, '2002-04-24' => 0, };

$fss->add_line('prices', 'array_data1', $line1, 'Three points');
$fss->add_line('prices', 'array_data2', $line2, 'Four points');
$fss->add_line('volumes', 'array_data3', $line3, 'Volume points', $offset);
$fss->add_line('cycles', 'array_data4', $line4, 'Cycle points');
$fss->add_line('tests', 'array_data5', $line5, 'Signal points');
is_same( $fss->{lines}{prices}{array_data1}{data}, $line1, 'line1 stored' );
is_same( $fss->{lines}{prices}{array_data2}{data}, $line2, 'line2 stored' );
is_same( $fss->{lines}{volumes}{array_data3}{data}, $line3, 'line3 stored' );
is_same( $fss->{lines}{cycles}{array_data4}{data}, $line4, 'line4 stored' );
is_same( $fss->{lines}{tests}{array_data5}{data}, $line5, 'line5 stored' );
my $nlines = 0;
foreach my $g (qw(prices volumes cycles tests)) {
    $nlines += keys %{$fss->{lines}{$g}};
}
is( $nlines, 5+5, "$nlines function lines" );

### Finance::Shares::Chart
my $fsc = new Finance::Shares::Chart(
    file => $pf,
    sample => $fss,
    test => $test,
    dots_per_inch => 72,
    smallest => 4,
    background => [1, 1, 0.9],
    bgnd_outline => 0,
    glyph_ratio => 0.5,
    normal_font => {
	name => 'Helvetica',
	size => 10,
	color => [0.2, 0.4, 0.8],
    },
    heading_font => {
	name => 'TimesBold',
	size => 16,
	color => [0, 0, 0.4],
    },
    prices => {
	percent => 40,
	points => {
	    shape => 'stock2',
	    color => [ 1, 0, 0 ],
	    width => 1,
	},
	y_axis => {
	    heavy_color => 0.25,
	},
    },
    volumes => {
	percent => 30,
	bars => {
	    color => [ 0, 0.5, 0.1 ],
	    outer_width => 3,
	},
    },
    cycles => {
	percent => 15,
	show_dates => 1,
    },
    tests => {
	percent => 15,
    },
);
ok($fsc, 'Finance::Shares::Chart created');

### output
$fsc->build_chart();
is( ref($fsc->{prices}{pgk})  eq 'PostScript::Graph::Key', $fsc->visible_lines('prices')  > 0, 'prices key panel');
is( ref($fsc->{volumes}{pgk}) eq 'PostScript::Graph::Key', $fsc->visible_lines('volumes') > 0, 'volumes key panel');
is( ref($fsc->{cycles}{pgk})  eq 'PostScript::Graph::Key', $fsc->visible_lines('cycles')  > 0, 'cycles key panel');
is( ref($fsc->{tests}{pgk}) eq 'PostScript::Graph::Key', $fsc->visible_lines('tests') > 0, 'tests key panel');
if ($test) {
    my $t = $fsc->{test};
    is( $t->{nlines} + 5, $nlines, 'function lines built' );
    is( $t->{lines}{array_data1}, 3, 'line1 points' );
    is( $t->{lines}{array_data2}, 4, 'line2 points' );
}

$fsc->output($name);

### finish
my $psfile = check_file("$name.ps");
ok(-e $psfile, 'PostScript file created');

ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# the chart looks different?
warn "\nUse ghostview or similar to inspect results file:\n$psfile\n";

