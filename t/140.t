#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 19;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects);
use Finance::Shares::moving_average;
use Finance::Shares::multiline_mean;
use Finance::Shares::compare;

# Multiple pages
# mean of several values
# use of '*' and defaults in line names

my $filename  = 't/140';
my $morrison  = 't/mrw.csv';
my $sainsbury = 't/sbry.csv';
my $safeway   = 't/sfw.csv';
my $tesco     = 't/tsco.csv';
my $date      = 'default';

add_show_objects(
    'Finance::Shares::Line',
    'Finance::Shares::multiline_mean',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose  => 1,
    filename => $filename,
    null     => '<none>',

    dates => {
	start => '2003-04-01',
	end   => '2003-07-03',
	by    => 'weekdays',
	after => 5,
	#before => 0,
    },
    charts => [
    ],
    lines => [
	one => { 
	    function => 'moving_average',
	    graph    => 'price',
	    line     => 'close',
	    period   => 5,
	},
	average => { 
	    function => 'multiline_mean',
	    #line     => ['morrison/MRW.L/default/one', 'sainsbury/SBRY.L/default/one'],
	    line     => '*///one',
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
	morrison => {
	    source => $morrison,
	    page   => 'MRW',
	    stock  => 'MRW.L',
	    line   => 'compare',
	},
	sainsbury => {
	    source => $sainsbury,
	    page   => 'SBRY',
	    stock  => 'SBRY.L',
	    line   => 'compare',
	},
	safeway => {
	    source => $safeway,
	    page   => 'SFW',
	    stock  => 'SFW.L',
	    line   => 'compare',
	},
	tesco => {
	    source => $tesco,
	    page   => 'TSCO',
	    stock  => 'TSCO.L',
	    line   => 'compare',
	},
	summary => {
	    page   => 'retail',
	    stock  => '<none>',
	    source => '<none>',	    # prevent default source
	    lines  => 'average',
	},
    ],
);


my ($nlines, $npages, @files) = $fsm->build();
is(@files, 1, 'number of file returned');
is($npages, 5, 'number of pages returned');
is($nlines, 9, 'number of lines returned');

#warn $fsm->show_known_functions;
#warn $fsm->show_known_lines;
#warn $fsm->show_resource('stocks');

my $pnames = $fsm->{pname};
is(@$pnames, 5, 'number of pages internally');
is($pnames->[0], 'morrison/MRW.L/default', 'name of page 0');
is($pnames->[1], 'sainsbury/SBRY.L/default', 'name of page 1');
is($pnames->[2], 'safeway/SFW.L/default', 'name of page 2');
is($pnames->[3], 'tesco/TSCO.L/default', 'name of page 3');
is($pnames->[4], 'summary/<none>/default', 'name of page 4');

my $tesco_data = $fsm->{pfsd}[3];
is($tesco_data->name, 'tesco/TSCO.L/default/data', 'tesco data name');
is($tesco_data->nprices, 43, 'tesco data points');
my $tesco_lines = $fsm->{pfsls}[3];
is(@$tesco_lines, 2, 'tesco lines');	# 1 + 1 empty for tests
my $summary_data = $fsm->{pfsd}[4];
is($summary_data->name, 'summary/<none>/default/data', 'summary data name');
is($summary_data->nprices, 0, 'summary data points');
my $summary_lines = $fsm->{pfsls}[4];
is(@$summary_lines, 2, 'summary lines');

sub compare {
    my ($date, $zdate) = @_;
    my $q = $fsm->{pfsd}[0];
    my $i = $q->date_to_idx($date);
    my $zi = $q->date_to_idx($zdate);
    
    # extract moving average, compare and mean lines
    my (@mov, @comp, $mean);
    for (my $pp = 0; $pp <= 3; $pp++) {
	my $ar = $fsm->{pfsls}[$pp];
	my $c = $ar->[0][0];
	push @comp, $c->{data};
	my $fn = $c->function;
	my @deps = @{$fn->{line}};
	push @mov, $deps[1][0]->{data};
    }
    my $ar = $fsm->{pfsls}[4];
    $mean = $ar->[0][0]->{data};

    my $mn = $mean->[$i];
    my $mnz = $mean->[$zi];
    my (@calc, @res);
    for (my $pp = 0; $pp <= 3; $pp++) {
	my $mv = $mov[$pp][$i];
	my $mvz = $mov[$pp][$zi];
	$calc[$pp] = sprintf("%4.2f", ($mv - $mvz) - ($mn - $mnz));
	$res[$pp]  = sprintf("%4.2f", $comp[$pp][$i]);
    }
    return (\@calc, \@res);
}

$date = '2003-04-10';
my $zdate = '2003-06-03';
my ($c, $r) = compare($date, $zdate);
my ($mrwC, $sbryC, $sfwC, $tscoC) = @$c;
my ($mrwR, $sbryR, $sfwR, $tscoR) = @$r;
is($mrwC,  $mrwR,  "morrison $date is $mrwC");
is($sbryC, $sbryR, "sainsbury $date is $sbryC");
is($sfwC,  $sfwR,  "safeway $date is $sfwC");
is($tscoC, $tscoR, "tesco $date is $tscoC");

