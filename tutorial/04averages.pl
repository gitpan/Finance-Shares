#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Finance::Shares::Sample;
use Finance::Shares::Averages;
use Finance::Shares::Chart;

my $help;
my $stock = 'GM';
my $dates = 'days';
my $start = '2000-08-01';
my $end   = '2001-07-31';
my $mode  = 'cache';
my $usage = <<END;
Usage:
    $0 [ options ]

where options can be any (or none) of the following:
  -c <code>  |  --code=<code>    Stock code like 'BA.L'
  -d <dmw>   | --dates=<dmw>     'days', 'weeks' or 'months'
  -s <date>  | --start=<date>    First date, as 'YYYY-MM-DD'
  -e <date>  |   --end=<date>    Last date, as 'YYYY-MM-DD'
  -m <mode>  |  --mode=<mode>    'cache', 'offline' or 'online'
  -h         |  --help           Show this help
END

GetOptions (
    'help|h'    => \$help,
    'code|c=s'  => \$stock,
    'dates|d=s' => \$dates,
    'start|s=s' => \$start,
    'end|e=s'   => \$end,
    'mode|m=s'  => \$mode,
) or $help = 1;
print $usage and exit if $help;

# Create MySQL object giving access to the data
my $fss = new Finance::Shares::Sample(
    source => {
        user     => 'test',
        password => 'test',
        database => 'test',
    },

    mode        => $mode,
    symbol	=> $stock,
    start_date  => $start,
    end_date    => $end,
    dates_by    => $dates,
);

# Create Chart object showing the data
my $fsc = new Finance::Shares::Chart(
    sample          => $fss,
    background      => [ 1, 1, 0.9 ],
    bgnd_outline    => 1,
    dots_per_inch   => 72,
    file => {
        landscape => 1,
    },
    x_axis => {
	show_lines  => 0,
	show_year   => 1,
    },
    prices => {
        percent => 70,
        points => {
            width => 1.5,
            color => [ 0.4, 0.4, 0.7 ],
        },
    },
    volumes => {
        percent => 30,
        bars => {
            color => [ 0.5, 0.8, 0.6 ],
            width => 1,
        },
    },
);

# place your function(s) here

$fsc->output($stock);
print "$stock quotes from $start to $end saved as $stock.ps\n";

