#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 2;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::lowest;

# testing tests with code to be evaluated 

my $filename = 't/191';
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
	before => 0,
    },
    lines => [
	value => {
	    function => 'value',
	    value    => 409,
	    shown    => 1,
	},
	below => {
	    function => 'mark',
	    first_only => 1,
	    style => {
		point => {
		    color    => [0, 0, 1],
		    shape    => 'north',
		    size     => 10,
		    y_offset => -10,
		},
	    },
	},
    ],
    tests => [
	# NB: limited to only one mark() per code string at present
	test1 => q(
	    our $limit = $value;
	    mark($below, $low) if $low < $limit;
	),
    ],
    sample => {
	stock => $stock,
	tests => 'test1',
    },
);


my ($nlines, $npages, @files) = $fsm->build();
is($nlines, 2, 'Number of lines');

#show $fsm, $fsm->{pfsls}, 4;
my $mark_np = $fsm->{pfsls}[0][0][1]{npoints};
is($mark_np, 7, 'Number of points');


