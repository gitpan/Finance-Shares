#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 9;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::bollinger_band;

# testing bollinger bands

my $filename = 't/210';
my $csvfile  = 't/lgen.csv';
my $sample   = 'default';
my $stock    = 'LGEN.L';
my $date     = 'default';

add_show_objects(
    'Finance::Shares::Line',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,
    show_values => 1,

    sources => $csvfile,
    dates => {
	start => '2002-06-05',
	end   => '2002-12-31',
	by    => 'quotes',
	before => 0,
    },
    chart => {
	x_axis => {
	    show_lines => 1,
	    mid_width => 0,
	    mid_color => 1,
	},
	graphs => [
	    price => {
		gtype   => 'price',
		percent => 50,
		points => {
		    shape => 'close2',
		    width => 2,
		    color => 0,
		},
	    },
	    volume => {
		gtype   => 'volume',
		percent => 0,
	    },
	],
    },
    lines => [
	boll => {
	    function => 'bollinger_band',
	},
	sdband => {
	    function => 'bollinger_band',
	    sd       => '0.65',
	    period   => 10,
	},
    ],
    sample => {
	stock => $stock,
	line  => ['boll', 'sdband'],
    },
);


my ($nlines, $npages, @files) = $fsm->build();
#warn $fsm->show_model_lines;
is($nlines, 4, 'Number of lines');

my $line = $fsm->{pfsls}[0][0][0];
my $np = $line->{npoints};
is($np, 127, 'Bollinger points above');
#line_dump($line->{data}, "$filename-boll-hi.data");
ok(line_compare($line->{data}, "$filename-boll-hi.data"), 'boll-hi line');

$line = $fsm->{pfsls}[0][0][1];
$np = $line->{npoints};
is($np, 127, 'Bollinger points below');
#line_dump($line->{data}, "$filename-boll-lo.data");
ok(line_compare($line->{data}, "$filename-boll-lo.data"), 'boll-lo line');

$line = $fsm->{pfsls}[0][1][0];
$np = $line->{npoints};
is($np, 137, 'Std dev points above');
#line_dump($line->{data}, "$filename-band-hi.data");
ok(line_compare($line->{data}, "$filename-band-hi.data"), 'band-hi line');

$line = $fsm->{pfsls}[0][1][1];
$np = $line->{npoints};
is($np, 137, 'Std dev points below');
#line_dump($line->{data}, "$filename-band-lo.data");
ok(line_compare($line->{data}, "$filename-band-lo.data"), 'band-lo line');


