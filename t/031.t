#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 12;
use Finance::Shares::Model;
use Finance::Shares::Support qw(
    show add_show_objects
    array_from_file
);

my $filename = 't/031';

add_show_objects(
    'Finance::Shares::Code',
    'Finance::Shares::Line',
    'Finance::Shares::mark',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,

    code => [
	band => do('t/031-band.code'),
	test => do('t/031-test.code'),
    ],

    lines => [
	'band' => {
	    line   => [qw(open)],
	    out    => [qw(high low)],
	    offset => 12,
	},
	test => {
	    line => 'band',
	},
    ],

    sample => {
	stock    => 'VOD.L',
	source   => 't/vod.csv',
	code     => [qw(band test)],
	lines    => [qw(band test)],
    },
);


my ($nlines, $npages, @files) = $fsm->build();
#warn $fsm->show_model_lines;

is($npages, 1, 'Number of pages');
is($nlines, 4, 'Number of lines');

my $results = array_from_file('t/031.out');

my $expected = [
    q('default/VOD.L/default/test' details:),
    q(function = Finance::Shares::mark=HASH(0x88211d4)),
    q(line     = Finance::Shares::Line=HASH(0x8821324)),
    q(line name= default/VOD.L/default/test/default),
    q(fn name  = default/VOD.L/default/test),
    q(source lines:),
    q(= default/VOD.L/default/band/high),
    q(= default/VOD.L/default/band/low),
    q(output lines:),
    q(= default/VOD.L/default/test/default),
];

for (my $i = 0; $i <= $#$expected; $i++) {
    my $exp = $expected->[$i];
    my $res = $results->[$i];
    if ($exp =~ /=HASH/) {
	$exp =~ s/=HASH.+//;
	$res =~ s/=HASH.+//;
    }
    is($res, $exp, "line $i");
}

