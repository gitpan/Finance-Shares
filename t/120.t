#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 25;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show);
use Finance::Shares::moving_average;

# Lines which depend on data
# Lead times

my $filename = 't/120';
my $csvfile  = 't/shire.csv';
my $sample   = 'default';
my $stock    = 'SHP.L';
my $date     = 'default';

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,

    sources => $csvfile,
    dates => {
	start => '2003-04-01',
	end   => '2003-07-03',
	by    => 'weekdays',
	after => 5,
	#before => 0,
    },
    charts => [
    ],
    lines => [
	one => { 
	    function => 'moving_average',
	    graph    => 'price',
	    line     => 'close',
	    period   => 5,
	},
	two => { 
	    function => 'moving_average',
	    graph    => 'price',
	    line     => 'close',
	    period   => 20,
	},
	three => { 
	    function => 'moving_average',
	    graph    => 'volume',
	    line     => 'volume',
	    period   => 10,
	},
    ],
    sample => {
	stock => $stock,
	lines => [qw(one two three)],
    },
);

my ($nlines, $npages, @files) = $fsm->build();

is($fsm->{ffile}[0],     $filename, 'psfile name');
is(ref($fsm->{fpsf}[0]), 'PostScript::File', 'PostScript::File');

my $page = "$sample/$stock/$date";
is($fsm->{pname}[0],     $page , 'page name');
is(ref($fsm->{pfsd}[0]), 'Finance::Shares::data', 'Finance::Shares::data');
is(ref($fsm->{pfsc}[0]), 'Finance::Shares::Chart', 'Finance::Shares::Chart');

my $data = $fsm->{pfsd}[0];
is($data->start, '2003-04-29', 'data start');
is($data->end,   '2003-07-07', 'data end');
is($data->first, '2003-04-01', 'data first');
is($data->last,  '2003-07-07', 'data last');
is($data->lines, 5, 'data lines');
is($data->line_ids, 5, 'data line_ids');
is($data->name, "$page/data", 'data name');
is($data->source, $csvfile, 'data source');

my @dl = $data->lines;
is($dl[0]->name, "$page/data/open",   'open line');
is($dl[1]->name, "$page/data/high",   'high line');
is($dl[2]->name, "$page/data/low",    'low line');
is($dl[3]->name, "$page/data/close",  'close line');
is($dl[4]->name, "$page/data/volume", 'volume line');

is(@{$fsm->{plines}[0]}, 3, 'number of lines');
is($fsm->{plines}[0][0], "$sample/$stock/$date/one", "first line");
is($fsm->{plines}[0][1], "$sample/$stock/$date/two", "second line");
is($fsm->{plines}[0][2], "$sample/$stock/$date/three", "third line");

my $line1 = $fsm->{pfsls}[0][0][0];
my $line2 = $fsm->{pfsls}[0][1][0];
my $line3 = $fsm->{pfsls}[0][2][0];
is($line1->name, "$page/one/mov", 'line 1 name');
is($line2->name, "$page/two/mov", 'line 2 name');
is($line3->name, "$page/three/mov", 'line 3 name');

