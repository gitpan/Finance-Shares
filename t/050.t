#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 27;
use Finance::Shares::Model;

# Input from both config file and options
# Some add entries to existing resource
# Both single and plural keys used
# Entries with same key over-written
# Options overwrites config file
# Cmdline overwrites options

my @args = ( 
    verbose => 6, 
    config => 't/050.conf' 
);

my $fsm = new Finance::Shares::Model( \@args,
    source => [
	morrisons => 't/ulvr.csv',
	sainsbury => 't/sbry.csv',
    ],
    source => 't/tsco.csv',
    sources => [
	morrisons => 't/mrw.csv',
	default => {
	    user     => 'test',
	    password => 'test',
	    database => 'test',
	},
    ],
    files => [
	mrw => 'morrisons',
	sbry => 'sainsbury',
    ],
);

is($fsm->{config},  't/050.conf', "config OK");
is($fsm->{filename}, 't/050', "filename OK");
is($fsm->{verbose}, 6, "verbose OK");

is(@{$fsm->{sources}},    6, "size 'sources' OK");
is(@{$fsm->{stocks}},     2, "size 'stocks' OK");
is(@{$fsm->{dates}},      2, "size 'dates' OK");
is(@{$fsm->{files}},      6, "size 'files' OK");
is(@{$fsm->{charts}},     2, "size 'charts' OK");
is(@{$fsm->{groups}},     2, "size 'groups' OK");
is(@{$fsm->{samples}},    2, "size 'samples' OK");
is(@{$fsm->{lines}},      0, "size 'lines' OK");
is(@{$fsm->{signals}},    0, "size 'signals' OK");
is(keys %{$fsm->{alias}}, 0, "size 'alias' OK");

is($fsm->{sources}[0],      'default',    "'sources' 0 OK");
is(ref($fsm->{sources}[1]), 'HASH',       "'sources' 1 OK");
is($fsm->{sources}[2],      'morrisons',  "'sources' 2 OK");
is($fsm->{sources}[3],      't/mrw.csv',  "'sources' 3 OK");
is($fsm->{sources}[4],      'sainsbury',  "'sources' 4 OK");
is($fsm->{sources}[5],      't/sbry.csv', "'sources' 5 OK");
is($fsm->{charts}[0],       'default',    "'charts' 0 OK");
is(ref($fsm->{charts}[1]),  'HASH',       "'charts' 1 OK");

is($fsm->{files}[0],        'default',    "'files' 0 OK");
is(ref($fsm->{files}[1]),   'HASH',       "'files' 1 OK");
is($fsm->{files}[2],        'mrw',        "'files' 2 OK");
is($fsm->{files}[3],        'morrisons',  "'files' 3 OK");
is($fsm->{files}[4],        'sbry',       "'files' 4 OK");
is($fsm->{files}[5],        'sainsbury',  "'files' 5 OK");
