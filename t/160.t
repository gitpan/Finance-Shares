#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 3;
use Finance::Shares::Model;
use Finance::Shares::Support qw(add_show_objects);

# Different date settings

add_show_objects(
    'Finance::Shares::Chart',
    'Finance::Shares::Line',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,

    source => 't/egg.csv',
    stocks => 'EGG.L',
    dates  => [
	quotes => {
	    start => '1999-01-05',
	    end   => '2000-10-24',
	    by    => 'quotes',
	},
	weekdays => {
	    start => '1999-01-05',
	    end   => '2000-10-24',
	    by    => 'weekdays',
	},
	days => {
	    start => '1999-01-05',
	    end   => '2000-10-24',
	    by    => 'days',
	},
	weeks => {
	    start => '1999-01-05',
	    end   => '2000-10-24',
	    by    => 'weeks',
	},
	months => {
	    start => '1999-01-05',
	    end   => '2000-10-24',
	    by    => 'months',
	},
    ],
    files  => 't/160',
    chart  => {
	graphs => [
	    price => {
		percent => 60,
		gtype   => 'price',
		points  => {
		    color => [0.3, 0.2, 0.6],
		}
	    },
	    volume => {
		percent => 40,
		gtype   => 'volume',
		bars    => {
		    color => [0.3, 0.2, 0.6],
		}
	    },
	],
    },

    sample => {
	dates => [qw(quotes weekdays weeks months)],
    },
);

my ($nlines, $npages, @files) = $fsm->build();
is(@files, 1, 'number of file returned');
is($npages, 4, 'number of pages returned');
is($nlines, 0, 'number of lines returned');

