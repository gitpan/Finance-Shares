#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 5;
use PostScript::Graph::Key 0.10 qw(split_lines);

my @labels = (
    '3 day simple average of Closing price crossing over 20 day exponential average of Closing price',
    'Buy signal',
    'And another long line that should wrap at least once',
);
my @count = (4, 1, 2);

my $pgk = new PostScript::Graph::Key(
    max_height	=> 100,
    item_labels	=> \@labels,
    text_width	=> 150,
    text_size	=> 10,
    glyph_ratio	=> 0.5,
);
ok($pgk, 'PostScript::Graph::Key created');
is($pgk->{nitems}, 7, 'Correct line total');

foreach my $i (0 .. $#labels) {
    my @lines = $pgk->wrapped_items($labels[$i]);
    is(@lines, $count[$i], "Correct lines for label $i");
}

