#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use TestFuncs qw(show is_same csv_to_sample check_filesize);
use PostScript::File 1.00 qw(check_file);
use Finance::Shares::Sample qw(line_id);
use Finance::Shares::Chart;
use Finance::Shares::Averages;

my $name = 't/ch03-dates';
my $source = 't/03-boc.csv';
my $test = {};	    # 0 to stop, {} to collect Chart test data
plan tests => 12;

### PostScript::File
my $pf = new PostScript::File(
    landscape => 1,
);
ok($pf, 'PostScript::File created');

### Finance::Shares::Sample
my $fss = new Finance::Shares::Sample(
    source => $source,
    symbol => 'BOC.L',
    dates_by => 'quotes',
);
ok( $fss, 'Finance::Shares::Sample created' );
is( $fss->start_date,'2002-01-02', 'start date' );
is( $fss->end_date,'2002-01-31', 'end date' );

my $csv = csv_to_sample($source);

my $ndates = keys %{$fss->{close}};
is( $ndates, keys %{$csv->{close}}, "$ndates dates" );

### Function lines
$fss->simple_average();
my $simple_5 = line_id('simple', 5, 'close');
ok( $fss->{lines}{prices}{$simple_5}, "$simple_5 stored" );
$fss->simple_average(period => 10);
my $simple_10 = line_id('simple', 10, 'close');
ok( $fss->{lines}{prices}{$simple_10}, "$simple_10 stored" );
$fss->simple_average(period => 20);
my $simple_20 = line_id('simple', 20, 'close');
ok( $fss->{lines}{prices}{$simple_20}, "$simple_20 stored" );
$fss->simple_average(graph => 'volumes', line => 'volume', period => 20);
my $volumes_20 = line_id('simple', 20, 'volume');
ok( $fss->{lines}{volumes}{$volumes_20}, "$volumes_20 stored" );

### Finance::Shares::Chart
my $fsc = new Finance::Shares::Chart(
    file => $pf,
    sample => $fss,
    test => $test,
    dots_per_inch => 72,
    smallest => 4,
    background => [1, 1, 0.9],
    bgnd_outline => 1,
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
	percent => 75,
	points => {
	    shape => 'stock2',
	    color => [ 1, 0, 0 ],
	    width => 3,
	},
	y_axis => {
	    heavy_color => 0.25,
	},
    },
    volumes => {
	percent => 25,
	bars => {
	    color => [ 0, 0.3, 0 ],
	    outer_width => 1,
	},
    },
);
ok($fsc, 'Finance::Shares::Chart created');

### output
$fsc->build_chart();


### finish
$fsc->output($name);
my $psfile = check_file("$name.ps");
ok(-e $psfile, 'PostScript file created');

ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# the chart looks different?
warn "\nUse ghostview or similar to inspect results file:\n$psfile\n";


