#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 5;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::sample_mean;

my $filename = 't/244';

add_show_objects(
    'Finance::Shares::Line',
    'Finance::Shares::mark',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,

    lines => [
	mean => {
	    function => 'sample_mean',
	    no_line  => 1,
	},
	relative => {
	    function => 'mark',
	    gtype    => 'analysis',
	    key      => 'Morrison relative to Tesco',
	    style    => {
		bar => {},
	    },
	},
    ],
   
    tests => [
	main => {
	    #verbose => 2,
	    before => q(
		my $mrw_mean = value($morrison/MRW.L/default/mean);
		my $tsco_mean = value($tesco/TSCO.L/default/mean);
		$self->{offset} = $tsco_mean - $mrw_mean;
 	    ),
	    during => q(
		my $mrw = $morrison/MRW.L/default/close;
		my $tsco = $tesco/TSCO.L/default/close;
		if (defined $mrw and defined $tsco) {
		    my $v = $mrw - $tsco + $self->{offset};
		    mark($relative, $v);
		}
	    ),
	    after => q(
	    ),
	},
    ],
    group => {
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
is($nlines, 10, 'Number of lines');

my $line;
my $dump = 1;
$line = $fsm->{ptfsls}[0][0];
cmp_ok( abs($line->value - 187.203), '<', 0.1, 'MRW.L sample mean');
$line = $fsm->{ptfsls}[0][1];
cmp_ok( abs($line->value - 199.081), '<', 0.1, 'TSCO.L sample mean');
$line = $fsm->{ptfsls}[0][4];
line_dump($line->{data}, "$filename.data") if $dump;
ok(line_compare($line->{data}, "$filename.data"), 'comparison line');


