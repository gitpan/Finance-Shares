#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 11;
use Finance::Shares::Model;
use Finance::Shares::Support qw(add_show_objects);

# Single sample defaulting to typical, simple values
# with no lines

add_show_objects(
    'Finance::Shares::Chart',
    'Finance::Shares::Line',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,

    source => 't/boc.csv',
    stocks => 'BOC.L',
    date   => {
	start => '2003-06-27',
	end   => '2003-09-05',
    },
    files  => 't/100',
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
);

my ($nlines, $npages, @files) = $fsm->build();

is($fsm->{ffile}[0], 't/100', 'filename OK');
is(ref($fsm->{fpsf}[0]), 'PostScript::File', 'PostScript::File');
is(@{$fsm->{fpages}[0]}, 1, 'number of pages stored');

is($fsm->{pname}[0], 'default/BOC.L/default', 'page name');
is(@{$fsm->{plines}[0]}, 0, 'number of lines stored');
is(ref($fsm->{pfsd}[0]), 'Finance::Shares::data', 'Finance::Shares::data');
is(ref($fsm->{pfsc}[0]), 'Finance::Shares::Chart', 'Finance::Shares::Chart');
is(@{$fsm->{pfsl}[0]}, 0, 'number of Finance::Shares::Lines');

is(@files, 1, 'number of files');
is($npages, 1, 'number of pages');
is($nlines, 0, 'number of lines');

#print $fsm->show_option('sources');
#print $fsm->show_option('stocks');
#print $fsm->show_option('dates');
#print $fsm->show_option('files');
#print $fsm->show_option('charts');
#print $fsm->show_option('groups');
#print $fsm->show_option('samples');
#print $fsm->show_option('lines');
#print $fsm->show_option('signals');
#print $fsm->show_aliases;


