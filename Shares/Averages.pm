package Finance::Shares::Averages;
our $VERSION = 0.13;
use strict;
use warnings;

package Finance::Shares::Sample;
use Finance::Shares::Sample 0.12 qw(%period %function %functype);

$function{simple_average}      = \&simple_average;
$function{weighted_average}    = \&weighted_average;
$function{exponential_average} = \&exponential_average;
$function{avg} = \&simple_average;
$function{wgt} = \&weighted_average;
$function{exp} = \&exponential_average;

$functype{simple_average}      = 'a';
$functype{weighted_average}    = 'a';
$functype{exponential_average} = 'a';
$functype{avg} = 'a';
$functype{wgt} = 'a';
$functype{exp} = 'a';

=head1 NAME

Finance::Shares::Averages - Moving average lines and tests

=head1 SYNOPSIS

    use Finance::Shares::Sample;
    use Finance::Shares::Averages;

    my $s = new Finance::Shares::Sample(...);

    my $id1 = $s->simple_average(
	graph  => 'prices',
	line   => 'close',
	period => 5,
	strict => 0,
	shown  => 1,
	style  => {...}, # PostScript::Graph::Style
	key    => 'My Momentum Line',
    );
    my $id2 = $s->weighted_average(...);
    my $id3 = $s->exponential_average(...);
    
=head1 DESCRIPTION

This package provides additional methods for L<Finance::Shares::Sample> objects.  The functions provide moving
average lines.  Once a line has been constructed it may be referred to by a text identifier returned by the
function.  The functions may also be referred to by their text names in a model specification (full or short
version):

    avg	    simple_average
    wgt	    weighted_average
    exp	    exponential_average

They all take the same parameters in hash key/value format.
All of these keys are optional.

=over 8

=item graph

A string indicating the graph for display: one of prices, volumes, cycles or signals.  (Default: 'prices')

=item line

A string indicating the data/function to be averaged - normally the closing prices.  (Default: 'close')

=item period

The number of readings used in making up the moving average.  The actual time spanned depends on how the sample
was configured.  (Default: 5)

=item strict

If 1, return undef if the average period is incomplete.  If 0, return the best value so far.  (Default: 1)

=item shown

A flag controlling whether the function is graphed.  0 to not show it, 1 to add the line to the named C<graph>.
(Default: 1)

=item style

A hash ref holding settings suitable for the PostScript::Graph::Style object used when drawing the line.
By default lines and points are plotted, with each line in a slightly different style.  (Default: undef)

=item key

If given this becomes the visual identifier, shown on the Chart key panel.

=back

=cut

sub simple_average {
    my $s = shift;
    die "No Finance::Shares::Sample object\n" unless ref($s) eq 'Finance::Shares::Sample';
    my %a = (
	strict	=> 1,
	shown	=> 1,
	graph	=> 'prices',
	line	=> 'close',
	period	=> 5,
	style	=> undef,
	key	=> undef,
	@_);
    
    my $base = $s->{lines}{$a{graph}}{$a{line}};
    die "No $a{graph} line '$a{line}'\n" unless $base;
    
    my $id = line_id('simple', $a{period}, $a{line});
    my $dtype = $s->dates_by();
    my $key = $a{key} ? $a{key} : "$a{period} $period{$dtype} simple average" . ($base->{key} ? " of $base->{key}" : '');
    my $data = $s->simple($a{strict}, $base, $a{period});
    
    $s->add_line( $a{graph}, $id, $data, $key, $a{style}, $a{shown} );
    return $id;
}

=head2 simple_average

Produce a series of values representing a simple moving average over the entire sample period.
An arithmetical mean of the previous C<period> values is calculated.

Nothing is done if there are no suitable data in the sample.  Returns the hash key identifying the line to
Finance::Shares::Sample.

=cut

sub weighted_average {
    my $s = shift;
    die "No Finance::Shares::Sample object\n" unless ref($s) eq 'Finance::Shares::Sample';
    my %a = (
	strict	=> 1,
	shown	=> 1,
	graph	=> 'prices',
	line	=> 'close',
	period	=> 5,
	style	=> undef,
	key	=> undef,
	@_);
    
    my $base = $s->{lines}{$a{graph}}{$a{line}};
    die "No $a{graph} line with if $a{line}\n" unless $base;
    
    my $id = line_id('weighted', $a{period}, $a{line});
    my $dtype = $s->dates_by();
    my $key = $a{key} ? $a{key} : "$a{period} $period{$dtype} weighted average" . ($base->{key} ? " of $base->{key}" : '');
    my $data = $s->weighted($a{strict}, $base, $a{period});
    
    $s->add_line( $a{graph}, $id, $data, $key, $a{style}, $a{shown} );
    return $id;
}

=head2 weighted_average

Produce a series of values representing a weighted moving average over the entire sample period.
This is like a simple moving average except that the most recent values carry more weight.

Nothing is done if there are no suitable data in the sample.  Returns the hash key identifying the line to
Finance::Shares::Sample.

=cut

sub exponential_average {
    my $s = shift;
    die "No Finance::Shares::Sample object\n" unless ref($s) eq 'Finance::Shares::Sample';
    my %a = (
	strict	=> 1,
	shown	=> 1,
	graph	=> 'prices',
	line	=> 'close',
	period	=> 5,
	style	=> undef,
	key	=> undef,
	@_);
    
    my $base = $s->{lines}{$a{graph}}{$a{line}};
    die "No $a{graph} line with id $a{line}\n" unless $base;
    
    my $id = line_id('expo', $a{period}, $a{line});
    my $dtype = $s->dates_by();
    my $key = $a{key} ? $a{key} : "$a{period} $period{$dtype} exponential average" . ($base->{key} ? " of $base->{key}" : '');
    my $data = $s->expo($a{strict}, $base, $a{period});
    
    $s->add_line( $a{graph}, $id, $data, $key, $a{style}, $a{shown} );
    return $id;
}

=head2 exponential_average

Produce a series of values representing an exponential moving average over the entire sample period.
Unlike a weighted average, all of the previous values are taken into accound.  C<period> affects how quickly the
weighting falls off.

Nothing is done if there are no suitable data in the sample.  Returns the hash key identifying the line to
Finance::Shares::Sample.

=cut

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
