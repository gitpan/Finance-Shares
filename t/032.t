#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 4;
use Finance::Shares::Model;
use Finance::Shares::Support qw(
    show add_show_objects
    line_dump line_compare
);

my $filename = 't/032';

add_show_objects(
    'Finance::Shares::Code',
    'Finance::Shares::Line',
    'Finance::Shares::mark',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,
    null => 'NULL',

    code => [
	curve => {
	    before => q(
		$self->{y}  = 0;
		$self->{dy} = 3;
		$self->{k} = 0.1;
	    ),
	    step => q(
		$self->{zero} = $close unless defined $self->{zero};
		my $y = $self->{zero} + $self->{y};
		mark('curve', $y);
		$self->{y}  += $self->{dy};
		$self->{dy} -= $self->{y} * $self->{k};
	    ),
	},
	delay => {
	    before => q(
		my $fn = info('delay', 'function');
		$self->{offset} = $fn->{offset} || 5;
		my @lines = info('delay', 'sources', 1);
		die "No source line" unless $lines[0];
		$self->{data} = $lines[0]->data;
	    ),
	    step => q(
		my $v = $self->{data}[$i];
		#warn "v=$v";
		my $j = $i - $self->{offset};
		if ($j >= 0) {
		    my $v = $self->{data}[$j];
		    mark('delay', $v);
		}
	    ),
	},
    ],

    lines => [
	curve => {
	},
	delay => {
	    line => 'curve',
	    offset => 1,
	},
    ],

    sample => {
	#stock  => 'VOD.L',
	#source => 't/vod.csv',
	stock => 'NULL',
	source => 'NULL',
	code   => [qw(curve delay)],
    },
);


my ($nlines, $npages, @files) = $fsm->build();
#warn $fsm->show_model_lines;

is($npages, 1, 'Number of pages');
is($nlines, 3, 'Number of lines');

my $dump = 0;
my $line;
$line = $fsm->{ptfsls}[0][2];
is($line->{npoints}, 60, 'points in delayed curve');
line_dump($line->{data}, "$filename.data") if $dump;
ok(line_compare($line->{data}, "$filename.data"), 'delayed curve');
