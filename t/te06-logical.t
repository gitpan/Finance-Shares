#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 13;
use TestFuncs qw(show show_hash show_lines csv_to_sample check_filesize);
use PostScript::File 0.11 qw(check_file);
use Finance::Shares::Model;
use Finance::Shares::Sample;
use Finance::Shares::Averages;
use Finance::Shares::Chart;

my $name = 't/te06-logical';
my $source = 't/07-ulvr.csv';
my $outfile;
open($outfile, '>', "$name.signals");

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

my $fast = $fss->simple_average(period => 3, style => $style, key => 'fast', strict => 1, shown => 1);
ok( $fss->{lines}{prices}{$fast}, "$fast stored" );
my $mid = $fss->simple_average(period => 8, style => $midstyle, key => 'mid', strict => 1, shown => 1);
ok( $fss->{lines}{prices}{$mid}, "$mid stored" );
my $slow = $fss->simple_average(period => 30, style => $style, key => 'slow', strict => 1, shown => 1);
ok( $fss->{lines}{prices}{$slow}, "$slow stored" );

### Level 1 tests
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

### Signals
$fsm->add_signal('rise', 'print_values', undef, {
    message => '$date: fast=<fast>, mid=<mid>, slow=<slow>', 
    lines   => {
	'<fast>' => 'prices::Fast',
	'<mid>'  => 'prices::Mid',
	'<slow>' => 'prices::Slow',
    },
    masks   => {
	'<fast>' => '%6.3f',
	'<mid>'  => '%7.2f',
	'<slow>' => '%8.1f',
    },
    file    => $outfile,
});
$fsm->add_signal('fall', 'print_values', undef, {
    message => '$date: Mid below fast at prices::Mid, value=$value',
    lines   => 'prices::Mid',
    masks   => '%d',
    mask    => '%6.2f',
    file    => $outfile,
});
$fsm->add_signal('down', 'mark_sell', undef, {
    graph => 'cycles',
});

sub custom_func {
    my ($id, $date, $value) = @_;
    print $outfile "From custom_func: $id, $date, $value\n";
}
$fsm->add_signal('func', 'custom', \&custom_func);

### Level 2 tests
my $combistyle = {
    sequence => $sigseq,
    same => 1,
    line => {
	width => 5,
	dashes => [],
    },
};

my $logic = $fsm->test(
    graph1 => 'signals', line1 => $test2,
    graph  => 'prices',
    test   => 'logic',
    style  => $combistyle,
    signal => 'rise',
    shown => 1,
);
ok( $fss->choose_line('prices', $logic, 1), 'logic line' );

my $not = $fsm->test(
    graph1 => 'signals', line1 => $test2,
    graph  => 'cycles',
    test   => 'not',
    style  => $combistyle,
    shown  => 1,
    signal => [qw(fall down func)],
);
ok( $fss->choose_line('cycles', $not, 1), "'not' line" );

my $and = $fsm->test(
    graph1 => 'signals', line1 => $test1,
    graph2 => 'signals', line2 => $test2,
    graph  => 'signals',
    test   => 'and',
    style  => $combistyle,
    shown => 1,
);
ok( $fss->choose_line('signals', $and, 1), 'test1 and test2' );

my $or = $fsm->test(
    graph1 => 'signals', line1 => $test1,
    graph2 => 'signals', line2 => $test2,
    graph  => 'signals',
    test   => 'or',
    style  => $combistyle,
    signal => 'func',
    shown => 1,
);
ok( $fss->choose_line('signals', $or, 1), 'test1 or test2' );

### Draw chart
my $fsc = new Finance::Shares::Chart(
    sample => $fss,
    invert => 1,
    file => {
	landscape => 1,
    },
    prices => {
	percent => 30,
    },
    volumes => {
	percent => 0,
    },
    cycles => {
	percent => 30,
    },
    signals => {
	percent => 40,
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
is( $count, 20, "$count known lines" );

close $outfile;
open($outfile, '<', "$name.signals");
$count = 0;
while (<$outfile>) {
    $count++;
}
close $outfile;
is( $count, 18, "$count saved signals" );

### Finish
$fsc->build_chart();
$fsc->output($name);
my $psfile = check_file("$name.ps");

ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# does the chart looks different?
warn "\nUse ghostview or similar to inspect results file:\n$psfile\n";

