#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 14;
use TestFuncs qw(is_same csv_to_sample sample_to_csv);
use Finance::Shares::Sample;
use Text::CSV_XS;

my $source  = 't/06-egg.csv';
my $results = 't/sa04-results.csv';

my $s = new Finance::Shares::Sample(
    source => $source,
    symbol => 'EGG.L',
    dates_by => 'months',
);
ok(1, 'Sample built');
# Uncomment to write results
#sample_to_csv($s, $results);
#exit;

is($s->dates_by(), 'months', 'months');
is($s->start_date, '1996-02-29', 'start date');
is($s->end_date, '2000-10-24', 'end date');
is( keys %{$s->{close}}, 48, 'dates counted' );
is( keys %{$s->{lines}{prices}}, 4, 'prices lines counted');
is( keys %{$s->{lines}{volumes}}, 1, 'volumes lines counted');

my $csv = csv_to_sample($results);
my $accuracy = 0.1;
is_same($s->{open},  $csv->{open},  'open hash',  $accuracy);
is_same($s->{high},  $csv->{high},  'high hash',  $accuracy);
is_same($s->{low},   $csv->{low},   'low hash',   $accuracy);
is_same($s->{close}, $csv->{close}, 'close hash', $accuracy);
is_same($s->{lx}, $csv->{lx}, 'lx hash');
is_same($s->{dates}, $csv->{dates}, 'dates array');

my $count = 0;
print "\nKnown lines...\n";
foreach my $g (qw(prices volumes cycles signals)) {
    foreach my $lineid ( $s->known_lines($g) ) {
	print "$g : $lineid\n";
	$count++;
    };
}
is( $count, 5, "$count known lines" );


