#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 23;
use Finance::Shares::Model;
use Finance::Shares::Support qw(mysql_present show add_show_objects);

# Requires MySQL
# Simple sample with named resources
# and 2 value lines

SKIP: {
my $mysql = mysql_present( user => 'test', password => 'test', database => 'test' );
skip 'mysql database not available', 23 unless $mysql;

add_show_objects(
    'Finance::Shares::Line',
    'Finance::Shares::mean',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => 't/011',

    sources => {
	user     => 'test',
	password => 'test',
	database => 'test',
    },
    dates => [
	Q1 => {
	    start => '2003-01-01',
	    end   => '2003-03-31',
	    before => 0,
	},
    ],
    charts => [
	'50:50' => {
	    price  => { percent => 50,  gtype => 'price'  },
	    volume => { percent => 50,  gtype => 'volume' },
	},
    ],
    lines => [
	one => { 
	    function => 'value',
	    graph    => 'price',
	    value    => 288,
	},
	two => { 
	    function => 'value',
	    graph    => 'price',
	    value    => 313,
	},
    ],
    sample => {
	stock => 'MKS.L',
	lines => [qw(one two)],
    },
);


my ($nlines, $npages, @files) = $fsm->build();

is($fsm->{ffile}[0],     'default', 'filename');
is(ref($fsm->{fpsf}[0]), 'PostScript::File', 'PostScript::File');

is($fsm->{pname}[0],     'default/MKS.L/Q1', 'page name');
is(ref($fsm->{pfsd}[0]), 'Finance::Shares::data', 'Finance::Shares::data');
is(ref($fsm->{pfsc}[0]), 'Finance::Shares::Chart', 'Finance::Shares::Chart');
is(@{$fsm->{plines}[0]}, 2, 'number of lines');
is($fsm->{plines}[0][0], 'default/MKS.L/Q1/one', 'first line');
is($fsm->{plines}[0][1], 'default/MKS.L/Q1/two', 'second line');

my $data = $fsm->{pfsd}[0];
is($data->start, '2003-01-02', 'data start');
is($data->end,   '2003-03-31', 'data end');
is($data->first, '2003-01-02', 'data first');
is($data->last,  '2003-03-31', 'data last');
is($data->func_lines, 5, 'data lines');
is($data->line_ids, 5, 'data line_ids');
is($data->name, 'default/MKS.L/Q1/data', 'data name');
is(ref($data->{source}), 'Finance::Shares::MySQL', 'Finance::Shares::MySQL');

my @dl = $data->func_lines;
is($dl[0]->name, 'default/MKS.L/Q1/data/open',   'open line');
is($dl[1]->name, 'default/MKS.L/Q1/data/high',   'high line');
is($dl[2]->name, 'default/MKS.L/Q1/data/low',    'low line');
is($dl[3]->name, 'default/MKS.L/Q1/data/close',  'close line');
is($dl[4]->name, 'default/MKS.L/Q1/data/volume', 'volume line');

my $line1 = $fsm->{pfsls}[0][0][0];
my $line2 = $fsm->{pfsls}[0][1][0];
is($line1->name, 'default/MKS.L/Q1/one/line', 'line 1');
is($line2->name, 'default/MKS.L/Q1/two/line', 'line 2');

}
