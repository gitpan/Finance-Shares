#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 15;
use Finance::Shares::Model;
use Finance::Shares::Support qw(
    today_as_string is_date
);

# Particular date and sample entries have defaults filled
# The default group is considered

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
	ulvr  => 'ULVR.L',
	shell => 'SHEL.L',
    ],
    
    dates => [
	shell => {
	    start => '2003-06-27',
	    end   => '2003-09-05',
	    by    => 'days',
	    after => 5,
	},
	ulvr => {
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
	    lines => '5gt10',
	},
	manu => {
	    source => 'ulvr',
	    file => 'pre10',
	    chart  => 'one',
	},
    ],
    
    sample => {
    },
);

my $today = today_as_string();
is($fsm->{dates}[2], 'ulvr', "correct date entry OK");
my $date = $fsm->{dates}[3];
is(ref($date),   'HASH',     "date is hash");
is($date->{by},  'weekdays', "'by' OK");
is($date->{end}, $today,     "'end' OK");
ok(is_date($date->{start}),  "'start' is date");
cmp_ok($date->{start}, 'lt', $date->{end}, "'start' < 'end'");

is(@{$fsm->{sname}},   1, "size 'sname' OK");

is($fsm->{sname}[0],   'default', "'sname' 0 OK");
is($fsm->{ssource}[0], 'dbase',   "'ssource' 0 OK");
is($fsm->{scodes}[0],  'ulvr',    "'scodes' 0 OK");
is($fsm->{sdates}[0],  'shell',   "'sdates' 0 OK");
is($fsm->{sfname}[0],   'default',   "'sfname' 0 OK");
is($fsm->{schart}[0],  'one',     "'schart' 0 OK");
is($fsm->{spage}[0],   undef,     "'spage' 0 OK");
is($fsm->{slines}[0][0], '5gt10',    "'slines' 0 OK");

#print $fsm->show_option('sources');
#print $fsm->show_option('stocks');
#print $fsm->show_option('dates');
#print $fsm->show_option('files');
#print $fsm->show_option('charts');
#print $fsm->show_option('groups');
#print $fsm->show_option('samples');
#print $fsm->show_option('lines');
#print $fsm->show_option('signals');
#print $fsm->show_aliases;

