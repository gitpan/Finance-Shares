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
my $usage = <<END;
Usage:
    $0 --stock=<code> --start=<YYYY-MM-DD> --end=<YYYY-MM-DD>
END

GetOptions (
    'help'    => \$help,
    'stock=s' => \$stock,
    'start=s' => \$start,
    'end=s'   => \$end,
);
print $usage and exit if $help;

# Create MySQL object giving access to the data
my $fss = new Finance::Shares::Sample(
    source => {
	user     => 'test',
	password => 'test',
	database => 'test',
	debug    => 2,
    },

    mode	=> 'cache',
    symbol    	=> $stock,
    start_date	=> $start,
    end_date	=> $end,
);

# Create Chart object showing the data
my $fsc = new Finance::Shares::Chart(
    sample => $fss,
);

$fsc->output($stock);
print "$stock quotes from $start to $end saved as $stock.ps\n";

