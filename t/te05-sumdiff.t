#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 11;
use TestFuncs qw(show show_hash show_lines csv_to_sample check_filesize);
use PostScript::File          1.00 qw(check_file);
use Finance::Shares::Model    0.12;
use Finance::Shares::Sample   0.12;
use Finance::Shares::Averages 0.12;
use Finance::Shares::Chart    0.14;

my $name = 't/te05-sumdiff';
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

### Signals test
my $sigseq = new PostScript::Graph::Sequence;
$sigseq->auto('color');
my $sigstyle = {
    sequence => $sigseq,
    same => 1,
    line => {
	dashes => [3,3,3,3],
	width => 3,
    },
};

my $test1 = $fsm->test(
    graph1 => 'prices', line1 => $mid,
    graph2 => 'prices', line2 => $slow,
    graph  => 'signals',
    test   => 'le',
    style  => $sigstyle,
    key => '(1) mid below slow',
    weight => 70,
    shown => 1,
);
ok( $fss->choose_line('signals', $test1, 1), 'test1 line' );

my $test2 = $fsm->test(
    graph1 => 'prices', line1 => $mid,
    graph2 => 'prices', line2 => $fast,
    graph  => 'signals',
    test   => 'ge',
    style  => $sigstyle,
    key => '(2) mid above fast',
    weight => 30,
    decay => 0.8,
    shown => 1,
);
ok( $fss->choose_line('signals', $test2, 1), 'test2 line' );

### Cycles
my $diffstyle = {
    bar => {
	color => [1,0,0.5],
    },
};

my $diff = $fsm->test(
    graph1 => 'prices', line1 => $slow,
    graph2 => 'prices', line2 => $fast,
    graph  => 'cycles',
    test   => 'diff',
    style  => $diffstyle,
    shown => 1,
    limit => 0,
);
ok( $fss->choose_line('cycles', $diff, 1), 'diff cycle line' );

### Combinations
my $combistyle = {
    sequence => $sigseq,
    same => 1,
    line => {
	width => 5,
	dashes => [],
    },
};

$fsm->add_signal('top', 'mark');

my $combi1 = $fsm->test(
    graph1 => 'signals', line1 => $test1,
    graph2 => 'signals', line2 => $test2,
    graph  => 'signals',
    test   => 'diff',
    style  => $combistyle,
    shown => 1,
);
ok( $fss->choose_line('signals', $combi1, 1), 'combi1 line' );

my $combi2 = $fsm->test(
    graph1 => 'signals', line1 => $test1,
    graph2 => 'signals', line2 => $test2,
    graph  => 'signals',
    test   => 'sum',
    style  => $combistyle,
    signals => ['top'],
    shown => 1,
);
ok( $fss->choose_line('signals', $combi2, 1), 'combi2 line' );

### Draw chart
my $fsc = new Finance::Shares::Chart(
    sample => $fss,
    file => {
	landscape => 1,
    },
    prices => {
	percent => 25,
    },
    volumes => {
	percent => 0,
    },
    cycles => {
	percent => 25,
    },
    signals => {
	percent => 50,
    },
);

my $count = 0;
print "Known lines...\n";
foreach my $g (qw(prices volumes cycles signals)) {
    foreach my $lineid ( $fss->known_lines($g) ) {
	print "  $g : $lineid\n";
	$count++;
    };
}
is( $count, 19, "$count known lines" );

### Finish
$fsc->build_chart();
$fsc->output($name);
my $psfile = check_file("$name.ps");

ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# does the chart looks different?
warn "\nUse ghostview or similar to inspect results file:\n$psfile\n";

