#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 22;
use Finance::Shares::Model;

# Multiple options testing preparation structure

my $fsm = new Finance::Shares::Model( \@ARGV,
    sources => [
	dbase => {
	    user     => 'test',
	    password => 'test',
	    database => 'test',
	},
	shell => 'shell.csv',
	ulvr  => 'ulvr.csv',
    ],
    
    stocks => [
	shell => 'SHEL.L',
	ulvr  => 'ULVR.L',
    ],
    
    dates => [
	shell => {
	    start  => '2003-06-27',
	    end    => '2003-09-05',
	    by     => 'days',
	    before => 20,
	    after  => 5,
	},
	ulvr => {
	    start  => '2002-04-02',
	    end    => '2002-09-30',
	    by     => 'weeks',
	},
    ],
    
    files => [
	pre10 => {
	    landscape => 0,
	},
    ],
    
    charts => [
	one => {
	    price  => { percent => 100, gtype => 'price'  },
	    volume => { percent => 0,   gtype => 'volume' },
	},
	two => {
	    price  => { percent => 50,  gtype => 'price'  },
	    volume => { percent => 50,  gtype => 'volume' },
	},
    ],
    
    lines => [
	'5day' => {
	    function => 'moving_average',
	    period => 5,
	},
	'10day' => {
	    function => 'moving_average',
	    period => 10,
	},
	'20day' => {
	    function => 'moving_average',
	    period => 20,
	},
	'5gt10' => {
	    function => 'gt',
	    lines    => ['5day', '10day'],
	    signals  => ['buy'],
	},
    ],
    
    signals => [
	'buy' => ['buy'],
	'print' => ['print'],
    ],
    
    groups => [
	chem => {
	    source => 'dbase',
	    file => 'pre10',
	    chart  => 'two',
	    lines => [qw(5day 10day)],
	},
	manu => {
	    source => 'ulvr',
	    file => 'pre10',
	    chart  => 'one',
	},
    ],
    
    samples => [
	shell => {
	    group => 'chem',
	    stock => 'SHEL.L',
	    date  => 'shell',
	},
	ulvr => {
	    group => 'manu',
	    stock => 'ULVR.L',
	    date  => 'ulvr',
	    lines => '20day',
	    page  => 'Unilever',
	},
    ],
);

is(@{$fsm->{sname}},   2, "size 'sname' OK");
is(@{$fsm->{ssource}}, 2, "size 'ssource' OK");
is(@{$fsm->{scodes}},  2, "size 'scodes' OK");
is(@{$fsm->{sdates}},  2, "size 'sdates' OK");
is(@{$fsm->{sfname}},   2, "size 'sfname' OK");
is(@{$fsm->{schart}},  2, "size 'schart' OK");
is(@{$fsm->{spage}},   2, "size 'spage' OK");
is(@{$fsm->{slines}},  2, "size 'slines' OK");

is($fsm->{sname}[0],   'shell',  "'sname' 0 OK");
is($fsm->{ssource}[0], 'dbase',  "'ssource' 0 OK");
is($fsm->{sdates}[0],  'shell',  "'sdates' 0 OK");
is($fsm->{sfname}[0],   'pre10',  "'sfname' 0 OK");
is($fsm->{schart}[0],  'two',    "'schart' 0 OK");
is($fsm->{spage}[0],   undef,    "'spage' 0 OK");
is(ref($fsm->{slines}[0]), 'ARRAY', "'slines' 0 OK");

is($fsm->{sname}[1],   'ulvr',  "'sname' 1 OK");
is($fsm->{ssource}[1], 'ulvr',  "'ssource' 1 OK");
is($fsm->{sdates}[1],  'ulvr',  "'sdates' 1 OK");
is($fsm->{sfname}[1],   'pre10',  "'sfname' 1 OK");
is($fsm->{schart}[1],  'one',    "'schart' 1 OK");
is($fsm->{spage}[1],   'Unilever', "'spage' 1 OK");
is($fsm->{slines}[1][0],  '20day', "'slines' 1 OK");


