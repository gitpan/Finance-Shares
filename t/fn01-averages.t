#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use TestFuncs qw(show is_same csv_to_sample check_filesize);
use PostScript::File 0.11 qw(check_file);
use Finance::Shares::Sample 0.10 qw(line_id);
use Finance::Shares::Chart  0.10;
use Finance::Shares::Averages 0.10;

my $name = 't/fn01-averages';
my $source = 't/05-boc.csv';
my $test = {};	    # 0 to stop, {} to collect Chart test data
plan tests => ($test ? 12 : 11);

### PostScript::File
my $pf = new PostScript::File(
    landscape => 1,
);
ok($pf, 'PostScript::File created');

### Finance::Shares::Sample
my $fss = new Finance::Shares::Sample(
    source => $source,
    symbol => 'BOC.L',
);
ok( $fss, 'Finance::Shares::Sample created' );
is( $fss->start_date,'2002-01-02', 'start date' );
is( $fss->end_date,'2002-09-05', 'end date' );

my $csv = csv_to_sample($source);

my $ndates = keys %{$fss->{close}};
is( $ndates, keys %{$csv->{close}}, "$ndates dates" );

### PostScript::Graph::Style
my $seq = new PostScript::Graph::Sequence;
$seq->auto(qw(green blue red));
my $style = {
    sequence => $seq,
    same => 1,
    line => {
	width => 2,
    },
    point => {
	shape => 'diamond',
	size => 4,
    },
};
my $pgs = new PostScript::Graph::Style(
    line => {
	outer_width => 5,
	inner_width => 3,
	inner_dashes => [12, 8, 4, 8],
	outer_dashes => [],
	outer_color => [0, 0.4, 0.4],
	inner_color => [0.6, 0.6, 1],
    },
);

### Function lines
my $simple = $fss->simple_average(period => 3, style => $style);
ok( $fss->{lines}{prices}{$simple}, "$simple stored" );
my $weighted = $fss->weighted_average(period => 10, style => $style);
ok( $fss->{lines}{prices}{$weighted}, "$weighted stored" );
my $expo = $fss->exponential_average(period => 21, style => $pgs);
ok( $fss->{lines}{prices}{$expo}, "$expo stored" );

### Finance::Shares::Chart
my $fsc = new Finance::Shares::Chart(
    file => $pf,
    sample => $fss,
    test => $test,
    dots_per_inch => 72,
    smallest => 12,
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
	sequence => $seq,
	points => {
	    shape => 'stock',
	    color => [ 1, 0, 0 ],
	    width => 2,
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
if ($test) {
    $fsc->{test}{style}{"prices_$simple"} =~ /^(\d)/;
    is( $1, $seq->id(), "style's sequence = $1" );
}

### finish
$fsc->output($name);
my $psfile = check_file("$name.ps");
ok(-e $psfile, 'PostScript file created');
ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# does the chart looks different?
warn "\nUse ghostview or similar to inspect results file:\n$psfile\n";

