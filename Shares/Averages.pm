package Finance::Shares::Averages;
our $VERSION = 0.11;
use strict;
use warnings;

package Finance::Shares::Sample;
use Carp;
use Finance::Shares::Sample 0.11 qw(%period %line);

$line{simple_a}   = \&simple_average;
$line{weighted_a} = \&weighted_average;
$line{expo_a}     = \&exponential_average;

=head1 NAME

Finance::Shares::Averages - Moving average lines and tests

=head1 SYNOPSIS

    use Finance::Shares::Sample;
    use Finance::Shares::Averages;

    my $s = new Finance::Shares::Sample(...);

    my $id1 = $s->simple_average(period => 4);
    my $id2 = $s->weighted_average(period => 4);
    my $id3 = $s->exponential_average(
	strict => 0,
	shown => 0,
	graph => 'prices',
	period => 4
    );
    
=head1 DESCRIPTION

This package provides additional methods for L<Finance::Shares::Sample> objects.  The functions provide moving
average lines.  Once a line has been constructed it may be referred to by a text identifier returned by the
function.

They all take the same parameters in hash key/value format.

=head1 FUNCTIONS

=cut

sub simple_average {
    my $s = shift;
    croak "No Finance::Shares::Sample object" unless ref($s) eq 'Finance::Shares::Sample';
    my %a = (
	strict	=> 0,
	shown	=> 1,
	graph	=> 'prices',
	line	=> 'close',
	period	=> 5,
	style	=> undef,
	id	=> undef,
	key	=> undef,
	@_);
    
    my $base = $s->{lines}{$a{graph}}{$a{line}};
    croak "No $a{graph} line '$a{line}'" unless $base;
    
    my $id = $a{id} ? $a{id} : line_id('simple', $a{period}, $a{line});
    my $dtype = $s->dates_by();
    my $key = $a{key} ? $a{key} : "$a{period} $period{$dtype} simple average" . ($base->{key} ? " of $base->{key}" : '');
    my $data = $s->simple($a{strict}, $base, $a{period});
    
    $s->add_line( $a{graph}, $id, $data, $key, $a{style}, $a{shown} );
    return $id;
}

=head2 simple_average

Produce a series of values representing a simple moving average over the entire sample period.
All of the following keys are optional.

=over 8

=item strict

If 1, return undef if the average period is incomplete.  If 0, return the best value so far.  (Default: 0)

=item shown

A flag controlling whether the function is graphed.  0 to not show it, 1 to add the line to the named C<graph>.
(Default: 1)

=item graph

A string indicating the graph for display: one of prices, volumes, cycles or signals.  (Default: 'prices')

=item line

A string indicating the data/function to be averaged - normally the closing prices.  (Default: 'close')

=item period

The number of readings used in making up the moving average.  The actual time spanned depends on how the sample
was configured.  (Default: 5)

=item style

A hash ref holding settings suitable for the PostScript::Graph::Style object used when drawing the line.
By default lines and points are plotted, with each line in a slightly different style.  (Default: undef)

=item id

If given this becomes the internal identifier for the line.  Where possible, allow the line to generate its own
identifier, using the value returned by the method.

=back

An arithmetical mean of the previous C<period> values is calculated.

Nothing is done if there are no suitable data in the sample.  Returns the hash key identifying the line to
Finance::Shares::Sample.

=cut

sub weighted_average {
    my $s = shift;
    croak "No Finance::Shares::Sample object" unless ref($s) eq 'Finance::Shares::Sample';
    my %a = (
	strict	=> 0,
	shown	=> 1,
	graph	=> 'prices',
	line	=> 'close',
	period	=> 5,
	style	=> undef,
	id	=> undef,
	key	=> undef,
	@_);
    
    my $base = $s->{lines}{$a{graph}}{$a{line}};
    croak "No $a{graph} line with if $a{line}" unless $base;
    
    my $id = $a{id} ? $a{id} : line_id('weighted', $a{period}, $a{line});
    my $dtype = $s->dates_by();
    my $key = $a{key} ? $a{key} : "$a{period} $period{$dtype} weighted average" . ($base->{key} ? " of $base->{key}" : '');
    my $data = $s->weighted($a{strict}, $base, $a{period});
    
    $s->add_line( $a{graph}, $id, $data, $key, $a{style}, $a{shown} );
    return $id;
}

=head2 weighted_average

Produce a series of values representing a weighted moving average over the entire sample period.
See B<simple_average> for parameters.

This is like a simple moving average except that the most recent values carry more weight.

Nothing is done if there are no suitable data in the sample.  Returns the hash key identifying the line to
Finance::Shares::Sample.

=cut

sub exponential_average {
    my $s = shift;
    croak "No Finance::Shares::Sample object" unless ref($s) eq 'Finance::Shares::Sample';
    my %a = (
	strict	=> 0,
	shown	=> 1,
	graph	=> 'prices',
	line	=> 'close',
	period	=> 5,
	style	=> undef,
	id	=> undef,
	key	=> undef,
	@_);
    
    my $base = $s->{lines}{$a{graph}}{$a{line}};
    croak "No $a{graph} line with id $a{line}" unless $base;
    
    my $id = $a{id} ? $a{id} : line_id('expo', $a{period}, $a{line});
    my $dtype = $s->dates_by();
    my $key = $a{key} ? $a{key} : "$a{period} $period{$dtype} exponential average" . ($base->{key} ? " of $base->{key}" : '');
    my $data = $s->expo($a{strict}, $base, $a{period});
    
    $s->add_line( $a{graph}, $id, $data, $key, $a{style}, $a{shown} );
    return $id;
}

=head2 exponential_average

Produce a series of values representing an exponential moving average over the entire sample period.
See B<simple_average> for parameters.

Unlike a weighted average, all of the previous values are taken into accound.  C<period> affects how quickly the
weighting falls off.

Nothing is done if there are no suitable data in the sample.  Returns the hash key identifying the line to
Finance::Shares::Sample.

=cut

sub support {
    my $s = shift;
    croak "No Finance::Shares::Sample object" unless ref($s) eq 'Finance::Shares::Sample';
    my %a = (
	shown	=> 1,
	strict	=> 0,
	graph	=> 'prices',
	line	=> 'close',
	period	=> 5,
	@_);
    
    my $base = $s->{lines}{$a{graph}}{$a{line}};
    croak "No $a{graph} line with id $a{line}" unless $base;
    
    my $id = $a{id} ? $a{id} : line_id('simple', $a{period}, $a{line});
    my $dtype = $s->dates_by();
    my $key = "$a{period} $period{$dtype} simple average" . ($base->{key} ? " of $base->{key}" : '');
    my ($support, $resistance) = $s->trend_lines($base, $a{period});
    
    $s->add_line( $a{graph}, $id, $support, $key, $a{style}, $a{shown} );
    return $id;
}

### SUPPORT METHODS

sub simple {
    my ($s, $strict, $hash, $period) = @_;

    my (@keys, @values);
    my $data = $hash->{data};
    foreach my $k (sort keys %$data ) {
	my $v = $data->{$k};
	push @keys, $k;
	push @values, $v;
    }
    my %points;
    my $start = 0;
    my $end = $#values;
    my ($total, $count) = (0, 0);
    my $first = $start;
    my $last = $end > $start + $period ? $start + $period : $end;
    for (my $i = $first; $i < $last; $i++) {
	$total += $values[$i];
	$count++;
	$points{$keys[$i]} = $total/$count unless $strict;
    }
    
    for (my $i = $last; $i <= $end; $i++) {
	my $old = $values[$i-$period];
	$total -= $old;
	$total += $values[$i];
	$points{$keys[$i]} = $total/$period;
    }

    return \%points;
}
# Internal method called by simple_average

sub weighted_single {
    my ($strict, $array, $period, $day) = @_;
    return undef if ($strict and $period > $day);
    
    my $total = 0;
    my $count = 0;
    my $base = $day - $period;
    for (my $i = $period; $i; $i--) {
	my $d = $base + $i;
	if ($d >= 0) {
	    $total += $i * $array->[$d];
	    $count += $i;
	}
    }

    return $total/$count;
}
# $day is index into dates array

sub weighted {
    my ($s, $strict, $hash, $period) = @_;

    my (@keys, @values);
    my $data = $hash->{data};
    foreach my $k (sort keys %$data ) {
	my $v = $data->{$k};
	push @keys, $k;
	push @values, $v;
    }
    my %points;
    for (my $i = 0; $i <= $#values; $i++) {
	$points{$keys[$i]} = weighted_single($strict, \@values, $period, $i);
    }
    
    return \%points;
}
# Internal method called by weighted_averages

sub expo {
    my ($s, $strict, $hash, $period) = @_;
    
    my (@keys, @values);
    my $data = $hash->{data};
    foreach my $k (sort keys %$data ) {
	my $v = $data->{$k};
	push @keys, $k;
	push @values, $v;
    }
    my %points;
    my $start = 0;
    my $end = $#values;
    my ($total, $count) = (0, 0);
    my $first = $start;
    my $last = $end > $start + $period ? $start + $period : $end;
    for (my $i = $first; $i < $last; $i++) {
	$total += $values[$i];
	$count++;
	$points{$keys[$i]} = $total/$count unless $strict;
    }
    
    my $value = $total/$count;
    my $weight = 1/$period;
    my $tweight = 1 - $weight;
    for (my $i = $last; $i <= $end; $i++) {
	$value = $value * $tweight + $values[$i] * $weight;
	$points{$keys[$i]} = $value;
    }

    return \%points;
}
# Internal method called by exponential_averages

sub identify_trends {
    my ( $s, $data, $trendlength ) = @_;
    my $dates = $s->{dates};
    my (@support, @resistance);
    
    foreach my $i (0 .. $#$dates-1) {
	my $date1  = $dates->[$i];
	my $price1 = $data->{$date1};
	my $count  = 0;
	my $trend  = 0;
	foreach my $j ($i .. $#$dates) {
	    my $date2  = $dates->[$j];
	    my $price2 = $data->{$date2};
	    my $diff = $price2 - $price1;
	    my $slope = ($diff > 0) ? +1 : (($diff < 0) ? -1 : 0);
	    if ($slope == $trend) {
		$count++;
	    } else {
		if ($trend && $count >= $trendlength) {
		    #print "$i $date1 ($price1), $date2 ($price2), slope=$slope, trend=$trend, count=$count\n";
		    my $h = {};
		    $h->{trend} = $trend;
		    $h->{start} = $date1;
		    $h->{end}   = $date2;
		    $h->{count} = $count;
		    if ($trend > 0) {
			push @support, $h;
		    } else {
			push @resistance, $h;
		    }
		    $count = 0;
		    $trend = $slope;
		    $i = $j;
		    last;
		} else {
		    $count = 0;
		    $trend = $slope;
		}
	    }
	}
    }
    return (\@support, \@resistance);
}

sub time_period {
    my ($strict, $period, $param) = @_;
    return defined($period) ? $period : 0;
}

=head1 BUGS

Please report those you find to the author.

=head1 AUTHOR

Chris Willmot, chris@willmot.org.uk

=head1 SEE ALSO

L<Finances::Shares::Sample>,
L<Finance::Shares::Chart>
and L<Finances::Shares::Model>.

There is also an introduction, L<Finance::Shares::Overview> and a tutorial beginning with
L<Finance::Shares::Lesson1>.

=cut

1;
