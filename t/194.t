#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 3;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);
use Finance::Shares::moving_average;

# testing tests
#   before/during/after code strings
#   printing to file

my $filename = 't/194';
my $csvfile  = 't/mrw.csv';
my $sample   = 'default';
my $stock    = 'MRW.L';
my $date     = 'default';

add_show_objects(
    #'PostScript::Graph::Style',
    #'Finance::Shares::Line',
    #'Finance::Shares::test',
    #'Finance::Shares::mark',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,
    show_values => 1,

    sources => $csvfile,
    dates => {
	start => '2003-04-01',
	end   => '2003-06-06',
	by    => 'quotes',
	before => 0,
    },
    lines => [
	value => {
	    function => 'value',
	    value    => 300,
	    shown    => 1,
	},
	mark => {
	    function => 'mark',
	    gtype    => 'price',
	    first_only => 0,
#	    style => {
#		bgnd_outline => 1,
#		point => {
#		    color    => [0, 0, 1],
#		    shape    => 'circle',
#		    size     => 12,
#		},
#	    },
	    order    => 99,
	},
	average => {
	    function => 'moving_average',
	    gtype    => 'price',
	    line     => 'close',
	},
    ],
    # NB: mark() must see undefined values in order to identify genuine 'fails'
    tests => [
	test1 => q(
	    mark($mark, $close) if $close > $average and defined $average;
	),
	test2 => {
	    before => <<END

		print "\$self->{stock} from \$self->{start} to \$self->{end}\\n";
		my \$name = "$filename.out";
		open( \$self->{fh}, '>', \$name ) or die "Unable to write to '\$name'";
END
	    ,
	    during => q(
		if ($close > $average and defined $average) {
		    mark($mark, $close);
		    my $fh = $self->{fh};
		    print $fh "close=$close, average=$average\n" if defined $close;
		}
	    ),
	    after  => qq(
		print "by \$self->{by}\\n";
		close \$self->{fh};
	    ),
	},
    ],
    sample => {
	stock => $stock,
	tests => [qw(test2)],
    },
);


my ($nlines, $npages, @files) = $fsm->build();
is($nlines, 2, 'Number of lines');

#show $fsm, $fsm->{pfsls}, 4;
my $mark_np = $fsm->{pfsls}[0][0][2]{npoints};
is($mark_np, 21, 'Number of points');

my $name = "$filename.out";
open( IN, '<', $name ) or die "Unable to open '$name'";
my $count = 0;
while (<IN>) { $count++ }
is($count, 21, 'Number of lines written');

