#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 8;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::maximum;
use Finance::Shares::minimum;
use Finance::Shares::standard_deviation;
use Finance::Shares::sample_mean;
use Finance::Shares::moving_average;
use Finance::Shares::weighted_average;
use Finance::Shares::exponential_average;

# testing no_line usage of maximum, minimum, standard_deviation, sample_mean
# and using a test on more than one page.
#
# Amongst other things, the test compares the price with the average, taking
# account of a margin which depends on the moving average error.  Why?  Just
# trying out the test/line interface.

my $filename = 't/242';
my $csvfile  = 't/mrw.csv';

add_show_objects(
    'Finance::Shares::Line',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,

    names => [
	min  => 'minimum',
	max  => 'maximum',
	sdev => 'standard_deviation',
	mean => 'sample_mean',
	mov  => 'moving_average',
	wgtd => 'weighted_average',
	expo => 'exponential_average',
    ],

    lines => [
	smoothed => {
	    function => 'expo',
	    period   => 10,
	},
	avg_mov => {
	    function => 'mean',
	    line     => 'smoothed',
	    no_line  => 1,
	},
	avg_price => {
	    function => 'mean',
	    no_line  => 1,
	},
	sdev_price => {
	    function => 'sdev',
	    no_line  => 1,
	},
	hi_mark => {
	    function => 'mark',
	    gtype    => 'price',
	    key      => 'High mark',
	},
	lo_mark => {
	    function => 'mark',
	    gtype    => 'price',
	    key      => 'Low mark',
	},
	relative => {
	    function => 'mark',
	    gtype    => 'analysis',
	    key      => 'price relative to average',
	    style    => {
		bar => {},
	    },
	},
    ],

   
    tests => [
	list => sub {
	    my $lines = shift;
	    for (my $i = 0; $i <= $#$lines; $i++) {
		my $l = $lines->[$i];
		my $fn = $l->function;
		print "$i ", $fn->name, ", built=$fn->{built}, value=", $fn->value() || '<undef>', "\n";
	    }
	},
	main => {
	    #verbose => 2,
	    before => q(
		my $adj = value($avg_mov);
		my $raw = $self->{avg} = value($avg_price);
		$self->{diff} = abs($adj - $raw);
		print "smoothed mean = ", $adj, "\n";
		print "     raw mean = ", $raw, "\n";
		print "   difference = ", $self->{diff}, "\n";
 	    ),
	    during => q(
		my $h = $smoothed + $self->{diff};
		my $l = $smoothed - $self->{diff};
		if (defined $close) {
		    mark($hi_mark, $h);
		    mark($lo_mark, $l);
		    my $offset = 0;
		    if ($close > $h) {
			$offset = $close - $h;
		    } elsif ($close < $l) {
			$offset = $close - $l;
		    }
		    mark($relative, $offset);
		}
	    ),
	    after => q(
		print " standard dev = ", value($sdev_price) || '<undef>', "\n";
		#call('list', $_l_);
	    ),
	},
    ],
    group => {
	lines    => [qw(smoothed)],
	test     => 'main',
	filename => $filename,
    },

    samples => [
	morrison => {
	    stock  => 'MRW.L',
	    source => 't/mrw.csv',
	},
	tesco => {
	    stock  => 'TSCO.L',
	    source => 't/tsco.csv',
	},
    ],
);


my ($nlines, $npages, @files) = $fsm->build();
#warn $fsm->show_model_lines;

is($npages, 2, 'Number of pages');
is($nlines, 18, 'Number of lines');

my $line;
my $dump = 0;
$line = $fsm->{ptfsls}[0][3];
is($line->{npoints}, 33, 'MRW.L high marks');
$line = $fsm->{ptfsls}[0][4];
is($line->{npoints}, 33, 'MRW.L low marks');
line_dump($line->{data}, "$filename-high.data") if $dump;
ok(line_compare($line->{data}, "$filename-high.data"), 'MRW.L high line');

$line = $fsm->{ptfsls}[1][4];
is($line->{npoints}, 33, 'TSCO.L low marks');
$line = $fsm->{ptfsls}[1][3];
is($line->{npoints}, 33, 'TSCO.L high marks');
line_dump($line->{data}, "$filename-low.data") if $dump;
ok(line_compare($line->{data}, "$filename-low.data"), 'TSCO.L low line');


