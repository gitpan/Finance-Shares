#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use TestFuncs qw(show show_lines csv_to_sample check_filesize);
use PostScript::File 0.11 qw(check_file);
use Finance::Shares::Sample   0.10 qw(line_id);
use Finance::Shares::Chart    0.10;
use Finance::Shares::Averages 0.10;
use Finance::Shares::Model    0.10;

my $name = 't/te02-below';
my $source = 't/01-shell.csv';
my $test = {};	    # 0 to stop, {} to collect Chart test data
plan tests => 13;
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
);
is( $fss->start_date,'2002-06-27', 'start date correct' );
is( $fss->end_date,'2002-09-05', 'end date correct' );

### PostScript::Graph::Style
my $gseq = new PostScript::Graph::Sequence;
my $green = {
    sequence => $gseq,
    same => 0,
    line => {
	color => [0.7,1,0.7],
	width => 1,
    },
};

my $oseq = new PostScript::Graph::Sequence;
my $orange = {
    sequence => $oseq,
    same => 0,
    line => {
	color => [1,0.9,0.5],
	width => 1,
    },
};


### Function lines
$fss->simple_average(period => 3);
my $simple_3 = line_id('simple', 3, 'close');
ok( $fss->{lines}{prices}{$simple_3}, "$simple_3 stored" );

$fss->simple_average(period => 20);
my $simple_20 = line_id('simple', 20, 'close');
ok( $fss->{lines}{prices}{$simple_20}, "$simple_20 stored" );

$fss->value(graph => 'volumes', value => 91000000, show => 1, style => $orange);
my $vol_91 = line_id('value', 91000000);
ok( $fss->{lines}{volumes}{$vol_91}, "$vol_91 stored" );
my $volumes = line_id('volume');

### Finance::Shares::Model
my $fsm = new Finance::Shares::Model;
$fsm->add_sample($fss);
is( values %{$fsm->{samples}}, 1, '1 Sample stored');

$fsm->add_signal('mark_buy');
$fsm->add_signal('mark_sell');

### Tests
my $sell = line_id('below', 'prices', $simple_3, 'prices', $simple_20);
$fsm->test( graph1 => 'prices', line1 => $simple_3,
		graph2 => 'prices', line2 => $simple_20,
		test => 'lt', signal => 'mark_sell', weight => 100,
		decay => 1.890, ramp => -90, 
		graph => 'signals', line => $sell, key => undef,
		style => $orange, shown => 1, );
ok( $fss->{lines}{signals}{$sell}, "$sell stored" );
is( values %{$fss->{lines}{signals}{$sell}{data}}, $ndates, "$ndates points in $sell" );

my $buy = line_id('above', 'prices', $simple_3, 'prices', $simple_20);
$fsm->test( graph1 => 'prices', line1 => $simple_3,
		graph2 => 'prices', line2 => $simple_20,
		test => 'gt', signal => 'mark_buy', weight => 100,
		decay => 1.890, ramp => -90, 
		graph => 'signals', line => $buy, key => undef,
		style => $green, shown => 1, );
ok( $fss->{lines}{signals}{$buy}, "$buy stored" );
is( values %{$fss->{lines}{signals}{$buy}{data}}, $ndates, "$ndates points in $buy" );

my $vol = line_id('above', 'volumes', $volumes, 'volumes', $vol_91);
$fsm->test( graph1 => 'volumes', line1 => $volumes,
		graph2 => 'volumes', line2 => $vol_91,
		test => 'gt', signal => 'mark_buy', weight => 90,
		decay => 1.890, ramp => -89, 
		graph => 'volumes', line => $vol, key => undef,
		style => $green, shown => 1, );
ok( $fss->{lines}{volumes}{$vol}, "$vol stored" );
is( values %{$fss->{lines}{volumes}{$vol}{data}}, $ndates, "$ndates points in $vol" );

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
	percent => 40,
	points => {
	    shape => 'close',
	    color => [ 1, 0, 0 ],
	    width => 2,
	},
    },
    volumes => {
	percent => 20,
	bars => {
	    color => [ 0, 0.3, 0 ],
	    outer_width => 1,
	},
    },
    signals => {
	percent => 20,
	show_dates => 1,
    },
);

### output
$fsc->build_chart();
#show_lines($fss);

### finish
$fsc->output($name);
my $psfile = check_file("$name.ps");

ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# does the chart looks different?
warn "Use ghostview or similar to inspect results file:\n$psfile\n";

print "\nKnown lines...\n";
foreach my $g (qw(prices volumes cycles signals)) {
    foreach my $lineid ( $fss->known_lines($g) ) {
	print "$g : $lineid\n";
    };
}


