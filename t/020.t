#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 3;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);

my $filename = 't/020';
my $csvfile  = 't/shire.csv';

add_show_objects(
    'Finance::Shares::Line',
    'Finance::Shares::mark',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,

    code => [
	first => q(
	    mark('first', $high);
	),
	band => q(
	    my $v = $first - 20 if defined $first;
	    mark('second', $v);
	),
    ],

    lines => [
	second => {
	    key => '20p lower than first',
	},
    ],
   
    sample => {
	stock    => 'SHP.L',
	source   => $csvfile,
	filename => $filename,
	code     => ['first', 'band'],
    },
);


my ($nlines, $npages, @files) = $fsm->build();
#warn $fsm->show_model_lines;

is($npages, 1, 'Number of pages');
is($nlines, 4, 'Number of lines');
# 'first' has 1 in, 1 out
# 'band'  has 1 in, 1 out

my $line;
my $dump = 0;
$line = $fsm->{ptfsls}[0][2];
line_dump($line->{data}, "$filename.data") if $dump;
ok(line_compare($line->{data}, "$filename.data"), 'lowered line');


