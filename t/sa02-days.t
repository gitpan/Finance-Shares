#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 14;
use TestFuncs qw (array_to_sample);
use Finance::Shares::Sample;

my $data = [
    ['2001-06-01',454.50,475.00,448.50,461.00,8535680],
    ['2001-06-04',465.00,465.00,458.50,459.00,3254045],
    ['2001-06-05',458.25,464.00,455.00,462.00,4615016],
    ];

my $s = new Finance::Shares::Sample(
    source => $data,
    symbol => 'TEST',
);
ok(1, 'Sample built');

is($s->dates_by, 'quotes', 'quotes by default');
is($s->start_date, '2001-06-01', 'start date');
is($s->end_date, '2001-06-05', 'end date');
is( keys %{$s->{close}}, 3, 'dates counted' );
is( keys %{$s->{lines}{prices}}, 4, 'prices lines counted');
is( keys %{$s->{lines}{volumes}}, 1, 'volumes lines counted');

my $hr = array_to_sample( $data );
is_deeply($s->{open}, $hr->{open}, 'open hash');
is_deeply($s->{high}, $hr->{high}, 'high hash');
is_deeply($s->{low}, $hr->{low}, 'low hash');
is_deeply($s->{close}, $hr->{close}, 'close hash');
is_deeply($s->{volume}, $hr->{volume}, 'volume hash');
is_deeply($s->{lx}, $hr->{lx}, 'lx hash');
is_deeply($s->{dates}, $hr->{dates}, 'dates array');

