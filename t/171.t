#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 3;
use Finance::Shares::Model;
use Finance::Shares::Support qw(mysql_present add_show_objects);

# Stocks from file (named resource)

SKIP: {
my $mysql = mysql_present( user => 'test', password => 'test', database => 'test' );
skip 'mysql database not available', 3 unless $mysql;

add_show_objects(
    'Finance::Shares::Chart',
    'Finance::Shares::Line',
);

my $file   = 't/171';
my $config = 't/170.conf';
my $stocks = 't/170.stocks';
my $start  = '2003-06-01';
my $end    = '2003-08-01';

my @args = ( 
    verbose  => 1, 
    config   => $config, 
);

my $fsm = new Finance::Shares::Model( \@args,
    filename => $file,
    dates  => [
	quotes => {
	    start => $start,
	    end   => $end,
	    by    => 'quotes',
	},
    ],
    stocks => [
	banks => $stocks,
    ],
    sample => {
	stock  => 'banks',
    },
);

my ($nlines, $npages, @files) = $fsm->build();
is(@files, 1, 'number of file returned');
is($npages, 2, 'number of pages returned');
is($nlines, 0, 'number of lines returned');

}

