#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 5;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::minimum;
use Finance::Shares::maximum;

# testing minimum, maximum

my $filename = 't/240';
my $csvfile  = 't/mrw.csv';
my $sample   = 'default';
my $stock    = 'MRW.L';
my $date     = 'default';

add_show_objects(
    'Finance::Shares::Line',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,
    sources => $csvfile,

    lines => [
	min_price => {
	    function => 'minimum',
	},
	max_price => {
	    function => 'maximum',
	},
	min_vol => {
	    function => 'minimum',
	    line     => 'volume',
	    gtype    => 'volume',
	},
	max_vol => {
	    function => 'maximum',
	    line     => 'volume',
	    gtype    => 'volume',
	},
	vol_mark => {
	    function => 'mark',
	    gtype    => 'volume',
	    style    => {},
	    key      => 'Inverted Volume',
	},
    ],
    test => {
	before => q(
	    print "Minimum price = ", value($min_price), "\n";
	    print "Maximum price = ", value($max_price), "\n";
	    
	    print "Minimum volume = ", value($min_vol), "\n";
	    print "Maximum volume = ", value($max_vol), "\n";

	    $self->{min_vol} = value($min_vol);
	    $self->{max_vol} = value($max_vol);
	    $self->{count}   = 0;
	    $self->{total}   = 0;
	),
	during => q(
	    $self->{count}++;
	    $self->{total} += $volume;
	    my $y = ($self->{min_vol} + $self->{max_vol} - $volume);
	    mark($vol_mark, $y) if defined $volume;
	),
	after => q(
	    print $self->{count}, " volume entries add up to ", $self->{total}, ".\n";
	    print "Giving and average of ", $self->{total}/$self->{count}, ".\n";
	),
    },
    sample => {
	stock => $stock,
	line  => [qw(min_price max_price min_vol max_vol)],
	test  => 'default',
    },
);


my ($nlines, $npages, @files) = $fsm->build();
is($nlines, 10, 'Number of lines');

#show $fsm, $fsm->{pfsls}, 4;
my $line = $fsm->{pfsls}[0][0][0];
is($line->function->value, '179.50', 'min price');

$line = $fsm->{pfsls}[0][1][0];
is($line->function->value, '197.00', 'max price');

$line = $fsm->{pfsls}[0][2][0];
is($line->function->value, '2197012', 'max volume');

$line = $fsm->{pfsls}[0][3][0];
is($line->function->value, '12766086', 'max volume');

