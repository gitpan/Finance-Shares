#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 14;
use TestFuncs qw(is_same csv_to_sample sample_to_csv);
use Finance::Shares::Sample 0.12;

my $source = 't/01-shell.csv';
my $results = 't/sa03-results.csv';

my $s = new Finance::Shares::Sample(
    source => $source,
    symbol => 'TEST',
    dates_by => 'weeks',
);
ok(1, 'Sample built');
# Uncomment to write results
#sample_to_csv($s, $results);
#exit;

my $csv = csv_to_sample($results);
is($s->dates_by(), 'weeks', 'weeks');
is($s->start_date, '2002-06-28', 'start date');
is($s->end_date, '2002-09-05', 'end date');
is( keys %{$s->{close}}, 11, 'dates counted' );
is( keys %{$s->{lines}{prices}}, 4, 'prices lines counted');
is( keys %{$s->{lines}{volumes}}, 1, 'volumes lines counted');

is_deeply($s->{open},   $csv->{open},   'open hash');
is_deeply($s->{high},   $csv->{high},   'high hash');
is_deeply($s->{low},    $csv->{low},    'low hash');
is_deeply($s->{close},  $csv->{close},  'close hash');
is_deeply($s->{volume}, $csv->{volume}, 'volume hash');
is_deeply($s->{lx},  $csv->{lx},  'lx hash');
is_deeply($s->{dates}, $csv->{dates}, 'dates array');

