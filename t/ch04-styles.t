#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use TestFuncs qw(show is_same csv_to_sample check_filesize);
use PostScript::File 0.11 qw(check_file);
use PostScript::Graph::Style 0.07;
use Finance::Shares::Sample 0.10 qw(line_id);
use Finance::Shares::Chart  0.10;
use Finance::Shares::Averages 0.10;

my $name = 't/ch04-styles';
my $source = 't/04-arm.csv';
my $test = {};	    # 0 to stop, {} to collect Chart test data
plan tests => 11;

### PostScript::File
my $pf = new PostScript::File(
    landscape => 1,
);

### Finance::Shares::Sample
my $fss = new Finance::Shares::Sample(
    source => $source,
    symbol => 'ARM.L',
);

### PostScript::Graph::Style
my $seq = new PostScript::Graph::Sequence;
$seq->auto('shape', 'dashes');
my $seq_id = $seq->id();
my $green = {
    #auto => [qw(shape)],
    same => 1,
    sequence => $seq,
    line => {
	color => [0,0.7,0.3],
	width => 2,
    },
    point => {
	#color => [0,0.4,0.2],
	size => 4,
    },
};

### Function lines
$fss->simple_average(period => 3, style => $green);
my $simple_3 = line_id('simple', 3, 'close');
ok( $fss->{lines}{prices}{$simple_3}, "$simple_3 stored" );

$fss->simple_average(period => 7, style => $green);
my $simple_7 = line_id('simple', 7, 'close');
ok( $fss->{lines}{prices}{$simple_7}, "$simple_7 stored" );

$fss->simple_average(period => 14, style => $green);
my $simple_14 = line_id('simple', 14, 'close');
ok( $fss->{lines}{prices}{$simple_14}, "$simple_14 stored" );

$fss->simple_average(period => 28, style => $green);
my $simple_28 = line_id('simple', 28, 'close');
ok( $fss->{lines}{prices}{$simple_28}, "$simple_28 stored" );

$fss->simple_average(period => 42, style => $green);
my $simple_42 = line_id('simple', 42, 'close');
ok( $fss->{lines}{prices}{$simple_42}, "$simple_42 stored" );

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
    key => {
	title => 'Simple averages',
	title_font => {
	    font => 'Courier-BoldOblique',
	},
	text_width => 70,
	background => [0.9,1,1],
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
);
$fsc->build_chart();

### testing styles
my $s3_line  = $fss->choose_line('prices', $simple_3);
my $s3_id    = $s3_line->{style}->id();
like($s3_id, qr/^$seq_id\.\d+/, "$s3_id in sequence $seq_id");
#warn "s3_line style = ", $s3_line->{style}->id(), "\n";

my $s7_line  = $fss->choose_line('prices', $simple_7);
my $s7_id    = $s7_line->{style}->id();
like($s7_id, qr/^$seq_id\.\d+/, "$s7_id in sequence $seq_id");
#warn "s7_line style = ", $s7_line->{style}->id(), "\n";

my $s14_line = $fss->choose_line('prices', $simple_14);
my $s14_id   = $s14_line->{style}->id();
like($s14_id, qr/^$seq_id\.\d+/, "$s14_id in sequence $seq_id");
#warn "s14_line style = ", $s14_line->{style}->id(), "\n";

my $s28_line = $fss->choose_line('prices', $simple_28);
my $s28_id   = $s28_line->{style}->id();
like($s28_id, qr/^$seq_id\.\d+/, "$s28_id in sequence $seq_id");
#warn "s28_line style = ", $s28_line->{style}->id(), "\n";

my $s42_line = $fss->choose_line('prices', $simple_42);
my $s42_id   = $s42_line->{style}->id();
like($s42_id, qr/^$seq_id\.\d+/, "$s42_id in sequence $seq_id");
#warn "s42_line style = ", $s42_line->{style}->id(), "\n";
#warn show([$seq->output_row()]);

### finish
$fsc->output($name);
my $psfile = check_file("$name.ps");

ok( check_filesize($psfile, -s $psfile), "filesize hasn't changed" );	# does the chart looks different?
warn "\nUse ghostview or similar to inspect results file:\n$psfile\n";

