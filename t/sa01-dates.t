#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 8;
use Finance::Shares::Sample 0.12 qw(today_as_string string_from_ymd ymd_from_string
		    increment_days increment_date days_difference day_of_week);
ok(1, 'Finance::Shares::Sample loaded');
		    
my ($secs, $mins, $hours, $day, $month, $year) = localtime;
my $now = sprintf("%04d-%02d-%02d", $year+1900, $month+1, $day);
#diag( "now = $now" );
is( today_as_string(), $now, 'today_as_string' );

my ($y1, $m1, $d1) = ymd_from_string($now);
#diag( "y1, m1, d1 = ($y1, $m1, $d1)" );
my $this_day = sprintf("%04d-%02d-%02d", $y1, $m1, $d1);
is( $this_day, $now, 'ymd_from_string' );

my $today = string_from_ymd($y1, $m1, $d1);
is( $today, $now, 'string_from_ymd' );

my ($y2, $m2, $d2) = increment_days($y1, $m1, $d1, 1);
#diag( "y2, m2, d2 = ($y2, $m2, $d2)" );
my $next_day = sprintf("%04d-%02d-%02d", $y2, $m2, $d2);
cmp_ok( $next_day, 'gt', $this_day, 'increment_days' );

my $tomorrow = string_from_ymd($y2, $m2, $d2);
#diag( "tomorrow = $tomorrow" );
is( $tomorrow, $next_day, 'string_from_ymd' );

my ($y3, $m3, $d3) = increment_days($y1, $m1, $d1, 7);
my $next_week = sprintf("%04d-%02d-%02d", $y3, $m3, $d3);
#diag( "next_week = $next_week" );
my $week_fwd = increment_date($now, 7);
is( $week_fwd, $next_week, 'increment_date' );

my $dow = day_of_week($y1, $m1, $d1);
#diag( "day of week = $dow" );
$dow = day_of_week(2003, 03, 18);
is( $dow, 2, 'day_of_week' );

