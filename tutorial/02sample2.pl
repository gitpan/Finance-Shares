#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Finance::Shares::Sample qw(increment_date);
use Finance::Shares::Chart;

my $help;
my $period = 20;
my $end    = '2002-01-31';
my $dates  = 'days';
my $usage  = <<END;
Usage:
    $0 [ options ] symbol

where options may include:
    --period=<num>
    --dates=[days|weeks|months]
    --end=<YYYY-MM-DD>

END

GetOptions (
    'help'    => \$help,
    'period=s'=> \$period,
    'dates=s' => \$dates,
    'end=s'   => \$end,
) or print $usage;
my $stock  = shift;
print $usage and exit if $help;
print $usage and exit unless $stock and $dates and $end;

my $days;
if ($dates eq 'months') {
    $days = $period/12 * 365;
} elsif ($dates eq 'weeks') {
    $days = $period * 7;
} else {
    $days = $period/5 * 7;
}
my $start = increment_date( $end, -$days );

# Create MySQL object giving access to the data
my $fss = new Finance::Shares::Sample(
    source => {
	user     => 'test',
	password => 'test',
	database => 'test',
    },

    symbol      => $stock,
    start_date	=> $start,
    end_date	=> $end,
    dates_by	=> $dates,
    mode	=> 'offline',
);

# Create Chart object showing the data
my $fsc = new Finance::Shares::Chart(
    sample  => $fss,
    file    => {
	landscape => 1,
    },
);

$fsc->output($stock);
print "$stock quotes from $start to $end saved as $stock.ps\n";

