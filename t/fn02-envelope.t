#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use TestFuncs qw(show is_same csv_to_sample check_filesize);
use PostScript::File 0.11 qw(check_file);
use Finance::Shares::Sample   0.10 qw(line_id);
use Finance::Shares::Chart    0.10;
use Finance::Shares::Averages 0.10;
use Finance::Shares::Bands    0.10;

my $name = 't/fn02-envelope';
my $source = 't/04-arm.csv';
my $test = {};	    # 0 to stop, {} to collect Chart test data
plan tests => ($test ? 10 : 10);
my $csv = csv_to_sample($source);

### PostScript::File
my $pf = new PostScript::File(
    landscape => 1,
);
ok($pf, 'PostScript::File created');

### Finance::Shares::Sample
my $fss = new Finance::Shares::Sample(
    source => $source,
    symbol => 'ARM.L',
);
ok( $fss, 'Finance::Shares::Sample created' );
is( $fss->start_date,'1998-01-02', 'start date' );
is( $fss->end_date,'1998-03-25', 'end date' );

my $ndates = keys %{$fss->{close}};
is( $ndates, keys %{$csv->{close}}, "$ndates dates" );

### PostScript::Graph::Style
my $seq = new PostScript::Graph::Sequence;
$seq->auto(qw(green blue red));
my $style = new PostScript::Graph::Style(
    sequence => $seq,
    same => 1,
    line => {
	width => 2,
    },
);

### Function lines
$fss->envelope(percent => 3, style => $style);
my $low = line_id('env_lo', 3, 'close');
ok( $fss->{lines}{prices}{$low}, "$low stored" );
my $high = line_id('env_hi', 3, 'close');
ok( $fss->{lines}{prices}{$high}, "$high stored" );

### Finance::Shares::Chart
my $fsc = new Finance::Shares::Chart(
    file => $pf,
    sample => $fss,
    test => $test,
    dots_per_inch => 72,
    smallest => 2,
    background => [1, 1, 0.9],
    prices => {
	percent => 75,
	sequence => $seq,
	points => {
	    shape => 'close',
	    color => [ 1, 0, 0 ],
	    width => 2,
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
ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# does the chart looks different?
warn "\nUse ghostview or similar to inspect results file:\n$psfile\n";

