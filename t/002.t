#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 23;
use Finance::Shares::Model;

# A few simple resources
# all default hashes with typical entries
# input only

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,

    source => 'shell.csv',
    stocks => 'SHEL.L',
    date   => {
	start => '2003-06-27',
	end   => '2003-09-05',
    },
    files  => 'in02',
    chart  => {
	price => {
	    percent => 60,
	    gtype   => 'price',
	},
	volume => {
	    percent => 40,
	    gtype   => 'volume',
	},
    },
    names  => [
	wally => 'jim',
    ],
);

is(@{$fsm->{sources}},    2, "size 'sources' OK");
is(@{$fsm->{stocks}},     2, "size 'stocks' OK");
is(@{$fsm->{dates}},      2, "size 'dates' OK");
is(@{$fsm->{files}},      2, "size 'files' OK");
is(@{$fsm->{charts}},     2, "size 'charts' OK");
is(@{$fsm->{groups}},     2, "size 'groups' OK");
is(@{$fsm->{samples}},    2, "size 'samples' OK");
is(@{$fsm->{lines}},      0, "size 'lines' OK");
is(@{$fsm->{codes}},      0, "size 'codes' OK");
is(keys %{$fsm->{alias}}, 1, "size 'alias' OK");

is($fsm->{sources}[0],     'default',    "'sources' 0 OK");
is($fsm->{sources}[1],     'shell.csv',  "'sources' 1 OK");
is($fsm->{stocks}[0],      'default',     "'stocks' 0 OK");
is($fsm->{stocks}[1],      'SHEL.L',     "'stocks' 1 OK");
is($fsm->{dates}[0],       'default',    "'dates' 0 OK");
is(ref($fsm->{dates}[1]),  'HASH',       "'dates' 1 OK");
is($fsm->{files}[0],       'default',    "'files' 0 OK");
is($fsm->{files}[1],       'in02',       "'files' 1 OK");
is($fsm->{charts}[0],      'default',    "'charts' 0 OK");
is(ref($fsm->{charts}[1]), 'HASH',       "'charts' 1 OK");
is($fsm->{lines}[0],       undef,        "'lines' 0 OK");
is($fsm->{signals}[0],     undef,        "'signals' 0 OK");
is($fsm->{alias}{wally},   'jim',        "'alias' entry OK");

