#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 14;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::bollinger_band;
use Finance::Shares::moving_average;

# Testing line names within tests:
#   fqln, wildcard, regexp, relative, aliased
#   including multiples, scalar and array variables;
# Passing data from before to after;
# Calling external subroutine, passing and returning value;
# Passing global variables to and from code fragment;

my $filename = 't/243';

$Finance::Shares::Support::variable_in = 999;
$Finance::Shares::Support::variable_out = 0;
$Finance::Shares::Support::variable_in = 999;	# stops warning

add_show_objects(
    'Finance::Shares::Line',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,

    lines => [
	avg => {
	    function => 'moving_average',
	},
	boll => {
	    function => 'bollinger_band',
	},
    ],
    
    tests => [
	default => {
	    before => q(
		$self->{l1} = $avg;
		$self->{l2} = $boll/high;
		$self->{l3} = [@*/*/*/close];
		$self->{l4} = [@.*/.*//volume];
		$self->{l5} = $morrison/MRW.L/default/close;
		$self->{l6} = $morrison/MRW.L/default/boll/low;
		$self->{l7} = $morrison/MRW.L/default/boll/low;
		$self->{l8} = $tesco///close;
		$self->{l9} = $data;
		$self->{la} = [@data];
	    ),
	    after => q(
		my $outfile = 't/243.out';
		open(OUT, '>', $outfile) or die "unable to write to '$outfile'";
		print OUT $self->{page}, "\n";
		print OUT $self->{l1}->name, "\n";
		print OUT $self->{l2}->name, "\n";
		print OUT call('printout', $self->{l3}), "\n";
		print OUT call('printout', $self->{l4}), "\n";
		print OUT $self->{l5}->name, "\n";
		print OUT $self->{l6}->name, "\n";
		print OUT $self->{l7}->name, "\n";
		print OUT $self->{l8}->name, "\n";
		print OUT $self->{l9}->name, "\n";
		print OUT call('printout', $self->{la}), "\n";
		print OUT "variable_in=", $Finance::Shares::Support::variable_in, "\n"; 
		close OUT;
		$Finance::Shares::Support::variable_out = 13; 
	    ),
	},
	printout => sub {
	    my ($ar) = @_;
	    my $res = '';
	    foreach my $line (@$ar) {
		$res .= ', ' if $res;
		$res .= $line->name;
	    }
	    return "($res)";
	},
    ],

    group => {
	test     => 'default',
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
is($nlines, 20, 'Number of lines');
is($Finance::Shares::Support::variable_out, 13, 'Variable passed');

my $line;
$line = $fsm->{ptfsls}[1][0];
is($line->name, 'tesco/TSCO.L/default/avg/mov', '$_l_->[0]');
$line = $fsm->{ptfsls}[1][1];
is($line->name, 'tesco/TSCO.L/default/boll/high', '$_l_->[1]');
$line = $fsm->{ptfsls}[1][2];
is($line->name, 'morrison/MRW.L/default/data/close', '$_l_->[2]');
$line = $fsm->{ptfsls}[1][3];
is($line->name, 'morrison/MRW.L/default/data/volume', '$_l_->[3]');
$line = $fsm->{ptfsls}[1][4];
is($line->name, 'tesco/TSCO.L/default/data/volume', '$_l_->[4]');
$line = $fsm->{ptfsls}[1][5];
is($line->name, 'morrison/MRW.L/default/boll/low', '$_l_->[5]');
$line = $fsm->{ptfsls}[1][6];
is($line->name, 'tesco/TSCO.L/default/data/close', '$_l_->[6]');
$line = $fsm->{ptfsls}[1][7];
is($line->name, 'tesco/TSCO.L/default/data/open', '$_l_->[7]');
$line = $fsm->{ptfsls}[1][8];
is($line->name, 'tesco/TSCO.L/default/data/high', '$_l_->[8]');
$line = $fsm->{ptfsls}[1][9];
is($line->name, 'tesco/TSCO.L/default/data/low', '$_l_->[9]');

my @expected = (
    'tesco/TSCO.L/default',
    'tesco/TSCO.L/default/avg/mov',
    'tesco/TSCO.L/default/boll/high',
    '(morrison/MRW.L/default/data/close)',
    '(morrison/MRW.L/default/data/volume, tesco/TSCO.L/default/data/volume)',
    'morrison/MRW.L/default/data/close',
    'morrison/MRW.L/default/boll/low',
    'morrison/MRW.L/default/boll/low',
    'tesco/TSCO.L/default/data/close',
    'tesco/TSCO.L/default/data/open',
    '(tesco/TSCO.L/default/data/open, tesco/TSCO.L/default/data/high, tesco/TSCO.L/default/data/low, tesco/TSCO.L/default/data/close, tesco/TSCO.L/default/data/volume)',
    'variable_in=999',
);

my $infile = 't/243.out';
open( IN, '<', $infile ) or die "Unable to read '$infile'";
my $test = 0;
my $total = 0;
while( <IN> ) {
    chomp;
    if ($expected[$test] eq $_) {
	$total++ 
    } else {
	diag "($test) expected: $expected[$test]";
	diag "           found: $_";
    }
    $test++;
}
is($total, $test, 'File as expected');

