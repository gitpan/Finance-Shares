#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 7;
use TestFuncs qw(show show_lines csv_to_sample check_filesize);
use PostScript::File 0.11 qw(check_file);
use Finance::Shares::Model;
use Finance::Shares::Sample;
use Finance::Shares::Bands;
use Finance::Shares::Chart;

my $name = 't/te03-synopsis';
my $source = 't/07-ulvr.csv';

my $fsm = new Finance::Shares::Model;

my $fss = new Finance::Shares::Sample(
    source => $source,
    symbol => 'ULVR.L',
);
$fsm->add_sample( $fss );
my $sid = $fss->id();
ok( $fsm->{samples}{$sid}, 'sample added');

$fsm->add_signal('mark_buy', undef, {
    graph => 'volumes',
    line  => 'volume',
    key   => 'above envelope',
    style => {
	point => {
	    color => [1, 0, 0],
	    shape => 'circle',
	    size  => 15,
	},
    },
});
is( @{$fsm->{sigfns}{'mark_buy'}}, 1, 'mark_buy signal added' );

my ($high, $low) = $fss->envelope();
ok( $fss->choose_line('prices', $high, 1), 'high envelope line' );
ok( $fss->choose_line('prices', $low, 1), 'low envelope line' );

my $tline = $fsm->test(
    graph1 => 'prices', line1 => 'high',
    graph2 => 'prices', line2 => $high,
    test   => 'ge',
    signal => [ 'mark_buy' ],
);
ok( $fss->choose_line('prices', $tline, 1), 'test line' );

my $fsc = new Finance::Shares::Chart(
    sample => $fss,
    file => {
	landscape => 1,
    },
);

my $count = 0;
print "\nKnown lines...\n";
foreach my $g (qw(prices volumes cycles signals)) {
    foreach my $lineid ( $fss->known_lines($g) ) {
	print "$g : $lineid\n";
	$count++;
    };
}
is( $count, 9, "$count known lines" );

### finish
$fsc->build_chart();
$fsc->output($name);
my $psfile = check_file("$name.ps");

ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# does the chart looks different?
warn "Use ghostview or similar to inspect results file:\n$psfile\n";



