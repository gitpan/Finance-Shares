#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 15;
use Finance::Shares::Model;
use Finance::Shares::Support qw(mysql_present show add_show_objects);
use Finance::Shares::moving_average;
use Finance::Shares::multiline_mean;
use Finance::Shares::compare;

# Multiple pages from single sample
# mean of several values
# use of '*' and defaults in line names
# hidden chart
# NOTE: uses MySQL database

my $filename  = 't/150';

SKIP: {
my $mysql = mysql_present( user => 'test', password => 'test', database => 'test' );
skip 'mysql database not available', 15 unless $mysql;

add_show_objects(
    'Finance::Shares::Line',
    'Finance::Shares::multiline_mean',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,

    source => {
	user     => 'test',
	password => 'test',
	database => 'test',
	#mode     => 'offline',
    },

    dates => {
	start => '2003-04-01',
	end   => '2003-07-03',
	by    => 'weekdays',
	after => 5,
	#before => 0,
    },
    charts => [
	default => {},
	hidden  => {
	    hidden => 1,
	},
    ],
    lines => [
	one => { 
	    function => 'moving_average',
	    graph    => 'price',
	    line     => 'close',
	    period   => 5,
	},
	two => { 
	    function => 'moving_average',
	    graph    => 'price',
	    line     => 'close',
	    period   => 20,
	},
	average => { 
	    function => 'multiline_mean',
	    line     => 'retail/*/default/one',
	    graph    => 'price',
	    key      => 'Average of retail stocks',
	},
	compare => {
	    function => 'compare',
	    line     => ['summary/<none>/default/average', 'one'],
	    zero     => '2003-06-01',
	},
    ],
    samples => [
	retail => {
	    stock  => [qw(MRW.L SBRY.L SFW.L TSCO.L)],
	    lines  => [qw(compare)],
	},
	summary => {
	    stock  => '<none>',
	    source => '<none>',
	    chart  => '<none>',
	    lines  => 'average',
	},
    ],
);


my ($nlines, $npages, @files) = $fsm->build();
is(@files, 1, 'number of file returned');
is($npages, 4, 'number of pages returned');
is($nlines, 9, 'number of lines returned');

#warn $fsm->show_known_functions;
#warn $fsm->show_known_lines;

my $pnames = $fsm->{pname};
is(@$pnames, 5, 'number of pages internally');
is($pnames->[0], 'retail/MRW.L/default', 'name of page 0');
is($pnames->[1], 'retail/SBRY.L/default', 'name of page 1');
is($pnames->[2], 'retail/SFW.L/default', 'name of page 2');
is($pnames->[3], 'retail/TSCO.L/default', 'name of page 3');
is($pnames->[4], 'summary/<none>/default', 'name of page 4');

my $tesco_data = $fsm->{pfsd}[3];
is($tesco_data->name, 'retail/TSCO.L/default/data', 'tesco data name');
is($tesco_data->nprices, 59, 'tesco data points');
my $tesco_lines = $fsm->{pfsls}[3];
is(@$tesco_lines, 2, 'tesco lines');
my $summary_data = $fsm->{pfsd}[4];
is($summary_data->name, 'summary/<none>/default/data', 'summary data name');
is($summary_data->nprices, 0, 'summary data points');
my $summary_lines = $fsm->{pfsls}[4];
is(@$summary_lines, 2, 'summary lines');

}

