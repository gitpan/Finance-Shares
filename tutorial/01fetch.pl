#!/usr/bin/perl
use strict;
use warnings;
use Finance::Shares::MySQL;

# Create MySQL object giving access to the data
my $db = new Finance::Shares::MySQL(
    user     => 'test',
    password => 'test',
    database => 'test',
    debug    => 2,
);

# Fetch the data from the internet
my @data = $db->fetch(
    symbol     => 'MSFT',
    start_date => '2003-01-01',
    end_date   => '2003-01-31',
);
die 'No data fetched' unless @data;

# Print out the data so you can see it's there
foreach my $row (@data) {
    my ($date, $open, $high, $low, $close, $volume) = @$row;
    printf('%s %6.2f,%6.2f,%6.2f,%6.2f, %d %s',
    $date, $open, $high, $low, $close, $volume, "\n");
}

