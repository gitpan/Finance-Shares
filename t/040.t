#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 18;
use Finance::Shares::Model;

# Typical, single entries from config file
# others filled with defaults

my $fsm = new Finance::Shares::Model( [ config => 't/040.conf'],
);


is($fsm->{config},  't/040.conf', "config OK");
is($fsm->{filename}, 't/040', "filename OK");

is(@{$fsm->{sources}},    2, "size 'sources' OK");
is(@{$fsm->{stocks}},     2, "size 'stocks' OK");
is(@{$fsm->{dates}},      2, "size 'dates' OK");
is(@{$fsm->{files}},      2, "size 'files' OK");
is(@{$fsm->{charts}},     2, "size 'charts' OK");
is(@{$fsm->{groups}},     2, "size 'groups' OK");
is(@{$fsm->{samples}},    2, "size 'samples' OK");
is(@{$fsm->{lines}},      0, "size 'lines' OK");
is(@{$fsm->{signals}},    0, "size 'signals' OK");
is(keys %{$fsm->{alias}}, 0, "size 'alias' OK");

is($fsm->{sources}[0],      'default', "'sources' 0 OK");
is(ref($fsm->{sources}[1]), 'HASH',    "'sources' 1 OK");
is($fsm->{files}[0],        'default', "'files' 0 OK");
is(ref($fsm->{files}[1]),   'HASH',    "'files' 1 OK");
is($fsm->{charts}[0],       'default', "'charts' 0 OK");
is(ref($fsm->{charts}[1]),  'HASH',    "'charts' 1 OK");

