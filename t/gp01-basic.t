#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 5;
use PostScript::File  0.1 qw(check_file);
use PostScript::Graph::Paper 0.08;
ok(1, 'PostScript::Graph::Paper loaded');

my $ps = new PostScript::Graph::Paper();
ok($ps, 'PostScript::Graph::Paper created');

my $name = "t/gp01-basic";
$ps->output( $name );
ok(1, 'output created');
my $file = check_file( "$name.ps" );
ok($file, "check_file returned $file");
ok(-e $file, "$file created");

