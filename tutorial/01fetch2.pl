#!/usr/bin/perl
use strict;
use warnings;
use Finance::Shares::MySQL;
use Getopt::Long;

my $start  = '';
my $end    = '';
my $usage  = <<END;
Usage:
    $0 --start=<YYYY-MM-DD> --end=<YYYY-MM-DD> <symbol>
END

GetOptions (
    'start=s' => \$start,
    'end=s'   => \$end,
) or print $usage;
my $symbol = shift;
die $usage unless $symbol and $start and $end;

# Create MySQL object giving access to the data
my $db = new Finance::Shares::MySQL(
    user     => 'test',
    password => 'test',
    database => 'test',
    debug => 2,
);

# Fetch the data from the internet
my @data = $db->fetch(
    symbol     => $symbol,
    start_date => $start,
    end_date   => $end,
    mode       => 'cache',
);
die 'No data fetched' unless @data;

