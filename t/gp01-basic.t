#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 5;
use PostScript::File         1.00 qw(check_file);
use PostScript::Graph::Paper 1.00;
ok(1, 'PostScript::Graph::Paper loaded');

my $ps = new PostScript::Graph::Paper();
ok($ps, 'PostScript::Graph::Paper created');

my $name = "t/gp01-basic";
$ps->output( $name );
ok(1, 'output created');
my $file = check_file( "$name.ps" );
ok($file, "check_file returned $file");
ok(-e $file, "$file created");

