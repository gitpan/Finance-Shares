#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 12;
use TestFuncs qw(is_same csv_to_sample sample_to_csv check_filesize);
use Finance::Shares::Sample;
use PostScript::File 0.11 qw(check_file);
use Finance::Shares::Chart  0.10;
use Text::CSV_XS;

my $name    = 't/sa04-results';
my $source  = 't/06-egg.csv';
my $results = 't/sa04-results.csv';

my $s = new Finance::Shares::Sample(
    source => $source,
    symbol => 'EGG.L',
    dates_by => 'months',
);
ok(1, 'Sample built');
# Uncomment to write results
#sample_to_csv($s, $results);
#exit;

is($s->dates_by(), 'months', 'months');
is($s->start_date, '1999-01-29', 'start date');
is($s->end_date, '2000-10-24', 'end date');
is( keys %{$s->{close}}, 13, 'dates counted' );
is( keys %{$s->{lines}{prices}}, 4, 'prices lines counted');
is( keys %{$s->{lines}{volumes}}, 1, 'volumes lines counted');

#my $csv = csv_to_sample($results);
#my $accuracy = 0.1;
#is_same($s->{open},  $csv->{open},  'open hash',  $accuracy);
#is_same($s->{high},  $csv->{high},  'high hash',  $accuracy);
#is_same($s->{low},   $csv->{low},   'low hash',   $accuracy);
#is_same($s->{close}, $csv->{close}, 'close hash', $accuracy);
#is_same($s->{lx}, $csv->{lx}, 'lx hash');
#is_same($s->{dates}, $csv->{dates}, 'dates array');

my $count = 0;
#print "\nKnown lines...\n";
foreach my $g (qw(prices volumes cycles signals)) {
    foreach my $lineid ( $s->known_lines($g) ) {
	#print "$g : $lineid\n";
	$count++;
    };
}
is( $count, 5, "$count known lines" );

### PostScript::File
my $pf = new PostScript::File(
    landscape => 1,
);
ok($pf, 'PostScript::File created');

### Finance::Shares::Chart
my $fsc = new Finance::Shares::Chart(
    file => $pf,
    sample => $s,
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


