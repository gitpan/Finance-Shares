#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 4;
use TestFuncs qw(is_same);

my $a1 = [ 1, undef, 2, 'three' ];
my $a2 = [ 1, undef, 2, 'three' ];
is_same($a1, $a2, 'shallow arrays');

my $h1 = { one => 1, two => 'two', three => 3, four => undef };
my $h2 = { one => 1, two => 'two', three => 3, four => undef };
is_same($h1, $h2, 'shallow hashes');

my $a3 = [ $a1, $h1 ];
my $a4 = [ $a2, $h2 ];
is_same($a3, $a4, 'deep arrays');

my $h3 = { five => $a1, six => $h1 };
my $h4 = { five => $a2, six => $h2 };
is_same($h3, $h4, 'deep hashes');


