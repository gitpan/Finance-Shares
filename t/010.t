#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 32;
use Finance::Shares::Model;

# No input at all - suitable defaults are created

my $fsm = new Finance::Shares::Model( [],
);

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

is($fsm->{sources}[0],      'default',    "'sources' 0 OK");
is($fsm->{sources}[1],      '',           "'sources' 1 OK");
is($fsm->{stocks}[0],       'default',    "'stocks' 0 OK");
is($fsm->{stocks}[1],       '',           "'stocks' 1 OK");
is($fsm->{dates}[0],        'default',    "'dates' 0 OK");
is(ref($fsm->{dates}[1]),   'HASH',       "'dates' 1 OK");
is($fsm->{files}[0],        'default',    "'files' 0 OK");
is(ref($fsm->{files}[1]),   'HASH',       "'files' 1 OK");
is($fsm->{charts}[0],       'default',    "'charts' 0 OK");
is(ref($fsm->{charts}[1]),  'HASH',       "'charts' 1 OK");
is($fsm->{groups}[0],       'default',    "'groups' 0 OK");
is(ref($fsm->{groups}[1]),  'HASH',       "'groups' 1 OK");
is($fsm->{samples}[0],      'default',    "'samples' 0 OK");
is(ref($fsm->{samples}[1]), 'HASH',       "'samples' 1 OK");


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

$fsm->build();

is($fsm->{fname}[0], 'default', 'filename OK');
is(ref($fsm->{fpsf}[0]), 'PostScript::File', 'PostScript::File OK');
is(@{$fsm->{fpages}[0]}, 1, 'number of pages OK');


is($fsm->{pname}[0], 'default/default/default', 'page name OK');
is(@{$fsm->{plines}[0]}, 0, 'number of lines OK');
is(ref($fsm->{pfsd}[0]), 'Finance::Shares::data', 'Finance::Shares::data OK');
is(ref($fsm->{pfsc}[0]), 'Finance::Shares::Chart', 'Finance::Shares::Chart OK');
is(@{$fsm->{pfsl}[0]}, 0, 'number of Finance::Shares::Lines OK');

