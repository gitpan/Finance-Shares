#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Finance::Shares::Sample;
use Finance::Shares::Chart;

my $help;
my $stock = 'MSFT';
my $start = '2002-01-01';
my $end   = '2002-01-31';
my $dates = 'days';
my $mode  = 'cache';
my $usage = <<END;
Usage:
    $0 [ options ]

where options can be any (or none) of the following
    --stock=<code>	    Stock code like 'BA.L'
    --dates=<dmw>	    'days', 'weeks' or 'months'
    --start=<YYYY-MM-DD>    First date of sample
      --end=<YYYY-MM-DD>    Last date of sample
     --mode=<mode>	    'cache', 'offline' or 'online'
END

GetOptions (
    'help'    => \$help,
    'stock=s' => \$stock,
    'dates=s' => \$dates,
    'start=s' => \$start,
    'end=s'   => \$end,
    'mode=s'  => \$mode,
) or $help = 1;
print $usage and exit if $help;

# Create MySQL object giving access to the data
my $fss = new Finance::Shares::Sample(
    source => {
	user     => 'test',
	password => 'test',
	database => 'test',
    },

    mode	=> $mode,
    symbol	=> $stock,
    start_date	=> $start,
    end_date	=> $end,
    dates_by	=> $dates,
);

# Create Chart object showing the data
my $fsc = new Finance::Shares::Chart(
    sample	=> $fss,
    background	=> 1,
    file    => {
	landscape => 1,
    },
    prices  => {
    },
    volumes => {
    },
);

$fsc->output($stock);
print "$stock quotes from $start to $end saved as $stock.ps\n";
