#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 14;
use TestFuncs qw(show show_hash show_lines csv_to_sample check_filesize);
use PostScript::File          1.00 qw(check_file);
use Finance::Shares::Model    0.12;
use Finance::Shares::Sample   0.12;
use Finance::Shares::Averages 0.12;
use Finance::Shares::Chart    0.14;

my $name = 't/te04-minmax';
my $source = 't/07-ulvr.csv';

### Sample
my $fsm = new Finance::Shares::Model;
my $fss = new Finance::Shares::Sample(
    source => $source,
    symbol => 'ULVR.L',
);
$fsm->add_sample( $fss );
my $sid = $fss->id();
ok( $fsm->{samples}{$sid}, 'sample added');

### Function lines
my $style = {
    same => 1,
    line => {
	width => 2,
	color => [1,0,0],
    },
};
my $midstyle = {
    auto => 0,
    line => {
	width => 1,
	color => [1,1,0],
    },
};

my $fast = $fss->simple_average(period => 3, style => $style, strict => 1, shown => 1);
ok( $fss->{lines}{prices}{$fast}, "$fast stored" );
my $mid = $fss->simple_average(period => 8, style => $midstyle, strict => 1, shown => 1);
ok( $fss->{lines}{prices}{$mid}, "$mid stored" );
my $slow = $fss->simple_average(period => 30, style => $style, strict => 1, shown => 1);
ok( $fss->{lines}{prices}{$slow}, "$slow stored" );

### Prices test
my $minline = $fsm->test(
    graph1 => 'prices', line1 => $fast,
    graph2 => 'prices', line2 => $mid,
    test   => 'min',
    style  => {
	auto => 'none',
	line => {
	    width => 3,
	    inner_color => [0,0,1],
	    outer_color => [0,0,1],
	},
    },
    key => 'min average',
    shown => 1,
);
ok( $fss->choose_line('prices', $minline, 1), 'min test line' );

my $maxline = $fsm->test(
    graph1 => 'prices', line1 => $fast,
    graph2 => 'prices', line2 => $mid,
    test   => 'max',
    style  => {
	auto => 'none',
	line => {
	    width => 3,
	    inner_color => [0,1,0],
	    outer_color => [0,1,0],
	},
    },
    key => 'max average',
    shown => 1,
);
ok( $fss->choose_line('prices', $maxline, 1), 'max test line' );

### Signals test
my $sigseq = new PostScript::Graph::Sequence;
$sigseq->auto('color');
my $sigstyle = {
    sequence => $sigseq,
    same => 0,
    point => {
	shape => 'dot',
	size => 6,
    },
};

my $test1 = $fsm->test(
    graph1 => 'prices', line1 => $mid,
    graph2 => 'prices', line2 => $slow,
    graph  => 'tests',
    test   => 'le',
    style  => $sigstyle,
    key => 'mid below slow',
    decay => 0.8,
    shown => 1,
);
ok( $fss->choose_line('tests', $test1, 1), 'test1 line' );

my $test2 = $fsm->test(
    graph1 => 'prices', line1 => $mid,
    graph2 => 'prices', line2 => $fast,
    graph  => 'tests',
    test   => 'ge',
    style  => $sigstyle,
    key => 'mid above fast',
    decay => 0.8,
    shown => 1,
);
ok( $fss->choose_line('tests', $test2, 1), 'test2 line' );

### Combination tests
$fsm->add_signal('sigmax', 'mark_buy', undef, {
    graph => 'tests',
    value => 99,
    key   => 'new maximum',
});
ok( $fsm->{sigfns}{'sigmax'}, 'mark_buy signal added' );
$fsm->add_signal('sigmin', 'mark_sell', undef, {
    graph => 'tests',
    value => 1,
    key   => 'new minimum',
});
ok( $fsm->{sigfns}{'sigmin'}, 'mark_sell signal added' );

### Combinations
my $combistyle = {
    sequence => $sigseq,
    same => 1,
    line => {
	width => 2,
	dashes => [],
    },
};

my $combi1 = $fsm->test(
    graph1 => 'tests', line1 => $test1,
    graph2 => 'tests', line2 => $test2,
    graph  => 'tests',
    test   => 'min',
    style  => $combistyle,
    key => 'min',
    signals => [ 'sigmin' ],
    shown => 1,
);
ok( $fss->choose_line('tests', $combi1, 1), 'combi1 line' );

my $combi2 = $fsm->test(
    graph1 => 'tests', line1 => $test1,
    graph2 => 'tests', line2 => $test2,
    graph  => 'tests',
    test   => 'max',
    style  => $combistyle,
    key => 'max',
    signals => [ 'sigmax' ],
    shown => 1,
);
ok( $fss->choose_line('tests', $combi2, 1), 'combi2 line' );

### Draw chart
my $fsc = new Finance::Shares::Chart(
    sample => $fss,
    file => {
	landscape => 1,
    },
    prices => {
	percent => 40,
	reverse => 1,
    },
    volumes => {
	percent => 20,
    },
    tests => {
	percent => 40,
	reverse => 1,
    },
);

my $count = 0;
#print "Known lines...\n";
foreach my $g (qw(prices volumes cycles tests)) {
    foreach my $lineid ( $fss->known_lines($g) ) {
	#print "  $g : $lineid\n";
	$count++;
    };
}
is( $count, 21, "$count known lines" );

### Finish
$fsc->build_chart();
$fsc->output($name);
my $psfile = check_file("$name.ps");

ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# does the chart looks different?
warn "\nUse ghostview or similar to inspect results file:\n$psfile\n";



