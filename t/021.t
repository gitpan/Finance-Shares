#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 7;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);

my $filename = 't/021';

add_show_objects(
    'Finance::Shares::Line',
    'Finance::Shares::mark',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,

    code => [
	test => q(
	    mark('Output line/one', 187);
	    mark('Output line/two', 193);
	),
    ],

    lines => [
    ],

    sample => {
	stock    => 'TSCO.L',
	source   => 't/tsco.csv',
	code     => 'test',
    },
);


my ($nlines, $npages, @files) = $fsm->build();
#warn $fsm->show_model_lines;

is($npages, 1, 'Number of pages');
is($nlines, 2, 'Number of lines');

my $line;
my $dump = 0;
$line = $fsm->{ptfsls}[0][0];
is( $line->{data}[0], 187, 'value 1' );
is( $line->{key}, "'Output line/one'", 'key 1' );
my $fn1 = $line->function; 
$line = $fsm->{ptfsls}[0][1];
is( $line->{data}[0], 193, 'value 1' );
is( $line->{key}, "'Output line/two'", 'key 2' );
my $fn2 = $line->function; 
is( $fn1, $fn2, 'same function' );


