#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 39;
use Finance::Shares::Model;

# More complex resources
# Some keys are plural
# Some are arrays holding several typical entries
# Input only - no build

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => 'in03',

    sources => {
	user     => 'test',
	password => 'test',
	database => 'test',
    },
    stock => [
	retail => [qw(NXT.L GUS.L)],
    ],
    dates => [
	nxt => {},
	default => {},
    ],
    file => {
	landscape => 0,
    },
    charts => [
	_one => {
	    price  => { percent => 100, gtype => 'price'  },
	    volume => { percent => 0,   gtype => 'volume' },
	},
	two => {
	    price  => { percent => 50,  gtype => 'price'  },
	    volume => { percent => 50,  gtype => 'volume' },
	},
    ],
    name   => [
	wally => 'jim',
	jo    => 'anne',
    ],
    line   => [
	first => {},
	_second => {},
    ],
    code => [
	xxx => '# some code',
    ],
    groups => {
	chart  => 'one',
	line   => [qw(first second)],
	source => 'default',
    },
    sample => {
	stock => 'MKS.L',
	page  => 'MKS',
    },
    date => [
	gus => {},
    ],
    lines => [
	third => {},
    ],
);

is($fsm->{verbose}, 1, "verbose OK");
is($fsm->{config},  undef, "config OK");
is($fsm->{filename}, 'in03', "filename OK");

is(@{$fsm->{sources}}, 2, "size 'sources' OK");
is(@{$fsm->{stocks}},  2, "size 'stocks' OK");
is(@{$fsm->{dates}},   6, "size 'dates' OK");
is(@{$fsm->{files}},   2, "size 'files' OK");
is(@{$fsm->{charts}},  4, "size 'charts' OK");
is(@{$fsm->{groups}},  2, "size 'groups' OK");
is(@{$fsm->{samples}}, 2, "size 'samples' OK");
is(@{$fsm->{lines}},   6, "size 'lines' OK");
is(@{$fsm->{codes}},   2, "size 'code' OK");
is(keys %{$fsm->{alias}}, 2, "size 'alias' OK");

is($fsm->{sources}[0],      'default', "'sources' 0 OK");
is(ref($fsm->{sources}[1]), 'HASH',    "'sources' 1 OK");
is($fsm->{stocks}[0],       'retail',  "'stocks' 0 OK");
is(ref($fsm->{stocks}[1]),  'ARRAY',   "'stocks' 1 OK");
is($fsm->{dates}[0],        'nxt',     "'dates' 0 OK");
is(ref($fsm->{dates}[1]),   'HASH',    "'dates' 1 OK");
is($fsm->{dates}[2],        'default', "'dates' 2 OK");
is(ref($fsm->{dates}[3]),   'HASH',    "'dates' 3 OK");
is($fsm->{dates}[4],        'gus',     "'dates' 4 OK");
is(ref($fsm->{dates}[5]),   'HASH',    "'dates' 5 OK");
is($fsm->{files}[0],        'default', "'files' 0 OK");
is(ref($fsm->{files}[1]),   'HASH',    "'files' 1 OK");
is($fsm->{charts}[0],       'one',     "'charts' 0 OK");
is(ref($fsm->{charts}[1]),  'HASH',    "'charts' 1 OK");
is($fsm->{charts}[2],       'two',     "'charts' 2 OK");
is(ref($fsm->{charts}[3]),  'HASH',    "'charts' 3 OK");
is($fsm->{lines}[0],        'first',   "'lines' 0 OK");
is(ref($fsm->{lines}[1]),   'HASH',    "'lines' 1 OK");
is($fsm->{lines}[2],        'second',  "'lines' 2 OK");
is(ref($fsm->{lines}[3]),   'HASH',    "'lines' 3 OK");
is($fsm->{codes}[0],        'xxx',     "'codes' 0 OK");
is(ref($fsm->{codes}[1]),   '',        "'codes' 1 OK");

is($fsm->find_option('charts', '_one'), undef, 'underscore removed');
is(ref($fsm->find_option('charts', 'one')), 'HASH', 'underscore converted');
is($fsm->find_option('lines', '_second'), undef, 'underscore removed');
is(ref($fsm->find_option('lines', 'second')), 'HASH', 'underscore converted');

#print $fsm->show_option('sources');
#print $fsm->show_option('stocks');
#print $fsm->show_option('dates');
#print $fsm->show_option('files');
#print $fsm->show_option('charts');
#print $fsm->show_option('groups');
#print $fsm->show_option('samples');
#print $fsm->show_option('lines');
#print $fsm->show_option('codes');
#print $fsm->show_aliases;

