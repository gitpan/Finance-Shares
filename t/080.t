#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 10;
use Finance::Shares::Model;
use Finance::Shares::Support qw(
    today_as_string is_date
    show
);

# literals in sample entry become resources

my $fsm = new Finance::Shares::Model( \@ARGV,

sample => {
    source => {
	    user     => 'test',
	    password => 'test',
	    database => 'test',
	},
    stocks => [ 'ULVR.L', 'SHEL.L' ],
    dates => [
	{
	    start => '2003-06-27',
	    end   => '2003-09-05',
	    by    => 'days',
	    after => 5,
	},
	{
	},
    ],
    file => 't/pre12',
    chart => {
	price  => { percent => 100, gtype => 'price'  },
	volume => { percent => 0,   gtype => 'volume' },
    },
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
},

);

is(@{$fsm->{dname}},   0, "size 'dname' OK");
is(@{$fsm->{sname}},   1, "size 'sname' OK");

is($fsm->{sname}[0],   'default',  "'sname' 0 OK");
is(ref($fsm->find_option('sources', $fsm->{ssource}[0])),  'HASH', "ssource 0 OK");
is(ref($fsm->find_option('stocks', $fsm->{scodes}[0])),  'ARRAY', "scodes 0 OK");
is(ref($fsm->find_option('dates', $fsm->{sdates}[0])),  'ARRAY', "sdates 0 OK");
is($fsm->find_option('files', $fsm->{sname}[0]),  'default', "sname 0 OK");
is(ref($fsm->{schart}[0]),  'HASH', "schart 0 OK");
is($fsm->{spage}[0],   undef,    "'spage' 0 OK");
is($fsm->{slines}[0][0],  '5day', "slines 0 OK");

#show "sample[0]=$fsm->{samples}[0]", $fsm->find_option('samples', $fsm->{samples}[0]);
#print $fsm->show_option('sources');
#print $fsm->show_option('stocks');
#print $fsm->show_option('dates');
#print $fsm->show_option('files');
#print $fsm->show_option('charts');
#print $fsm->show_option('groups');
#print $fsm->show_option('samples');
#print $fsm->show_option('lines');
#print $fsm->show_option('signals');

