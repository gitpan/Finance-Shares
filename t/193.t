#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 4;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::moving_average;

# testing tests
#   multiple tests
#   multiple marks in same code
#   custom function call
# display order

my $filename = 't/193';
my $csvfile  = 't/shire.csv';
my $sample   = 'default';
my $stock    = 'SHP.L';
my $date     = 'default';

add_show_objects(
    #'PostScript::Graph::Style',
    'Finance::Shares::Line',
    #'Finance::Shares::test',
    'Finance::Shares::mark',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,
    show_values => 1,

    sources => $csvfile,
    dates => {
	start => '2003-04-01',
	end   => '2003-06-06',
	by    => 'quotes',
	before => 0,
    },
    lines => [
	value => {
	    function => 'value',
	    value    => 420,
	    shown    => 1,
	    order    => -1,
	},
	below => {
	    function => 'mark',
	    gtype    => 'volume',
	    first_only => 0,
	    order    => 8,
	    key      => 'above average',
	    style    => 'circle',
	    order    => -8,
	},
	above => {
	    function => 'mark',
	    gtype    => 'price',
	    first_only => 1,
	    style => {
		point => {
		    color    => [0.2, 1, 0],
		    shape    => 'north',
		    size     => 8,
		    y_offset => -12,
		    width    => 3,
		},
	    },
	    order    => -9,
	},
	line => {
	    function => 'mark',
	    gtype    => 'volume',
	    key      => 'This line was generated from user code',
	    order    => -2,
	},
	vavg => {
	    function => 'moving_average',
	    gtype    => 'volume',
	    line     => 'volume',
	    style    => {
		line => {
		    inner_dashes => [ 6, 3, ],
		    width  => 2,
		    outer_color => [ 0.6, 0.6, 0.6 ],
		},
	    },
	    order    => -4,
	},
    ],
    # NB: mark() must see undefined values (eval as 0) to distinguish genuine 'fails'
    # Remember that dates by 'quotes' have no undefined values, by definition.
    code => [
	sub1 => sub {
	    my ($date, $high, $low) = @_;
	    #print "$date\: $low to $high\n";
	},

	test1 => q(
	    mark('above', 370) if $high > $value or not defined $high;
	    call('sub1', $self->{date}, $high, $low) if $low >= 290;
	),
	test2 => q(
	    my $val = $vavg * 2.5;
	    mark( 'line', $val ) if defined $vavg;
	    mark( 'below', $volume ) if $volume > 5000000;
	),
    ],
    sample => {
	stock => $stock,
	code  => [qw(test2 test1)],
    },
);


my ($nlines, $npages, @files) = $fsm->build();
#warn $fsm->show_model_lines;
is($nlines, 8, 'Number of lines');

my $mark_np = $fsm->{ptfsls}[0][1]{npoints};
is($mark_np, 56, 'Number of points');

$mark_np = $fsm->{ptfsls}[0][2]{npoints};
is($mark_np, 8, 'Number of points');

$mark_np = $fsm->{ptfsls}[0][4]{npoints};
is($mark_np, 5, 'Number of points');

