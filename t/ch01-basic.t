#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use TestFuncs qw(show is_same check_filesize);
use PostScript::File 0.11 qw(check_file);
use Finance::Shares::Sample 0.10;
use Finance::Shares::Chart  0.10;

my $name = 't/ch01-basic';
my $source = 't/01-shell.csv';
my $test = {};	    # 0 to stop, {} to collect Chart test data
plan tests => ($test ? 34 : 29);

### PostScript::File
my $pf = new PostScript::File(
    landscape => 1,
    #clipping => 1,
    #clip_command => 'stroke',
);
ok($pf, 'PostScript::File created');

### Finance::Shares::Sample
my $fss = new Finance::Shares::Sample(
    source => $source,
    symbol => 'SHEL.L',
    dates_by => 'quotes',
);
ok( $fss, 'Finance::Shares::Sample created' );
is( $fss->start_date,'2002-06-27', 'start date' );
is( $fss->end_date,'2002-09-05', 'end date' );
my $ndates = keys %{$fss->{close}};
is( $ndates, 50, "$ndates dates counted" );
is( keys %{$fss->{lines}{prices}}, 4, 'prices lines counted');
is( keys %{$fss->{lines}{volumes}}, 1, 'volumes lines counted');

### Finance::Shares::Chart
my $fsc = new Finance::Shares::Chart(
    file => $pf,
    sample => $fss,
    test => $test,
    dots_per_inch => 72,
    background => [1, 1, 0.9],
    bgnd_outline => 0,
    smallest => 4,
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
	    width => 2,
	},
    },
    volumes => {
	percent => 30,
	bars => {
	    color => [ 0, 0.5, 0.1 ],
	},
    },
    cycles => {
	percent => 15,
	show_dates => 1,
    },
    signals => {
	percent => 15,
    },
);
ok($fsc, 'Finance::Shares::Chart created');

### output
$fsc->build_chart();
$fsc->output($name);
like( $pf->{Functions}, qr/BeginProcSet: GraphKey/, 'GraphKey PostScript');
like( $pf->{Functions}, qr/BeginProcSet: GraphStyle/, 'GraphStyle PostScript');
like( $pf->{Functions}, qr/BeginProcSet: XYChart/, 'XYChart PostScript');
like( $pf->{Functions}, qr/BeginProcSet: StockChart/, 'StockChart PostScript');
ok( $fsc->{prices}{pgp}, 'prices graph');
ok( $fsc->{volumes}{pgp}, 'volumes graph');
ok( $fsc->{cycles}{pgp}, 'cycles graph');
ok( $fsc->{signals}{pgp}, 'signals graph');
ok( $fsc->{labels}, 'labels exist' );
is( @{$fsc->{labels}}, $ndates, "$ndates labels" );
ok( $fsc->{dlabels}, 'dummy labels exist' );
is( @{$fsc->{dlabels}}, $ndates, "$ndates dummy labels" );
is( $fsc->{lblspc}, 44, "space for labels" );

my @pagebox = $fsc->{pf}->get_page_bounding_box();
cmp_ok( $pagebox[3], '>=', $fsc->{prices}{layout}{top_edge}, 'top above prices' );
cmp_ok( $fsc->{prices}{layout}{bottom_edge}, '>=', $fsc->{volumes}{layout}{top_edge}, 'prices above volumes' );
cmp_ok( $fsc->{volumes}{layout}{bottom_edge}, '>=', $fsc->{cycles}{layout}{top_edge}, 'volumes above cycles' );
cmp_ok( $fsc->{cycles}{layout}{bottom_edge}, '>=', $fsc->{signals}{layout}{top_edge}, 'cycles above signals' );
cmp_ok( $fsc->{signals}{layout}{bottom_edge}, '>=', $pagebox[1], 'signals above bottom' );

if ($test) {
    my $accuracy = 0.01;
    is_same( $test->{prices_count}, $test->{volumes_count}, 'prices/volumes count' );
    is_same( $test->{prices_ymin},  389.48, 'prices ymin',  $accuracy );
    is_same( $test->{prices_ymax},  525.14, 'prices ymax',  $accuracy );
    is_same( $test->{volumes_ymin}, 219.98, 'volumes ymin', $accuracy );
    is_same( $test->{volumes_ymax}, 300.11, 'volumes ymax', $accuracy );
}

### finish
my $psfile = check_file("$name.ps");
ok(-e $psfile, 'PostScript file created');
ok(-s $psfile > 9999, 'basic PostScript written');

ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# the chart looks different?
warn "\nUse ghostview or similar to inspect results file:\n$psfile\n";

