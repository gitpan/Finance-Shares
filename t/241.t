#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 7;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::standard_deviation;

# testing standard_deviation

my $filename = 't/241';
my $csvfile  = 't/mrw.csv';
my $sample   = 'default';
my $stock    = 'MRW.L';
my $date     = 'default';

add_show_objects(
    'Finance::Shares::Line',
    'Finance::Shares::standard_deviation',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,
    sources => $csvfile,

    chart => {
	graphs => [
	    price => {
		gtype  => 'price',
		points => {
		    shape => 'stock2',
		    width => 2.5,
		    color => [0.8, 0.8, 1],
		},
	    },
	],
    },
    lines => [
	sd_price => {
	    function => 'standard_deviation',
	    order    => -2,
	    key      => 'Price distribution',
	},
	sd_volume => {
	    function => 'standard_deviation',
	    line     => 'volume',
	    gtype    => 'volume',
	    std_devs => [ 3, 2.5, 2, 0 ],
	    order    => -1,
	},
	price_range => {
	    function => 'mark',
	    gtype    => 'logic',
	    graph    => 'price range',
	    style    => {},
	    key      => 'Daily price range',
	},
	sd_range => {
	    function => 'standard_deviation',
	    line     => 'price_range',
	    graph    => 'price range',
	    std_devs => [ 2.5, 2, 0, -2, -2.5 ],
	    order    => -3,
	},
    ],
    code => [
	price_range => {
	    before => q(
		print "Std dev = ", value( $sd_price, 'std_dev'), "\n";
		print "Mean    = ", value( $sd_price, 'mean'), "\n";
	    ),
	    step => q(
		my $range = $high - $low;
		mark('price_range', $range) if defined $high;
	    ),
	},
    ],
    sample => {
	stock => $stock,
	lines => [qw(sd_price sd_volume sd_range)],
	codes => [qw(price_range)],
    },
);


my ($nlines, $npages, @files) = $fsm->build();
is($nlines, 23, 'Number of lines');

#warn $fsm->show_model_lines;

#show $fsm, $fsm->{pfsls}, 4;
my ($line, $val, $diff);
$line = $fsm->{pfsls}[0][0][0];
cmp_ok(abs($line->function->value('mean') - 187.203), '<', 0.1, 'sd_price mean');
cmp_ok(abs($line->function->value('std_dev') - 4.619), '<', 0.1, 'sd_price std_dev');

$line = $fsm->{pfsls}[0][1][0];
cmp_ok(abs($line->function->value('mean') - 6089209), '<', 1, 'sd_volume mean');
cmp_ok(abs($line->function->value('std_dev') - 2644501), '<', 1, 'sd_volume std_dev');

$line = $fsm->{pfsls}[0][2][0];
cmp_ok(abs($line->function->value('mean') - 6.973), '<', 0.1, 'sd_range mean');
cmp_ok(abs($line->function->value('std_dev') - 3.308), '<', 0.1, 'sd_range std_dev');

