#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 2;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::lowest;

# testing tests with code to be evaluated 

my $filename = 't/192';
my $csvfile  = 't/shire.csv';
my $sample   = 'default';
my $stock    = 'SHP.L';
my $date     = 'default';

add_show_objects(
    'PostScript::Graph::Style',
    'Finance::Shares::Line',
    'Finance::Shares::test',
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
	by    => 'days',
	#by    => 'quotes',
	before => 0,
    },
    lines => [
	value => {
	    function => 'value',
	    value    => 425,
	    shown    => 1,
	},
	oversold => {
	    function => 'mark',
	    first_only => 1,
	    style => {
		point => {
		    color    => [0, 0, 1],
		    shape    => 'south',
		    size     => 10,
		    y_offset => 10,
		},
	    },
	},
    ],
    # NB: mark() must see undefined values 
    # in order to distinguish genuine 'fails' from these
    # Of course, using by 'quotes' has no undefined values, by definition.
    tests => [
	near => q(
	    mark($oversold, $high) if $high > $value or not defined $high;
	),
    ],
    sample => {
	stock => $stock,
	#lines => 'lowest',
	tests => 'near',
    },
);


my ($nlines, $npages, @files) = $fsm->build();
is($nlines, 2, 'Number of lines');

#show $fsm, $fsm->{pfsls}, 4;
my $mark_np = $fsm->{pfsls}[0][0][0]{npoints};
is($mark_np, 4, 'Number of points');

