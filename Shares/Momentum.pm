package Finance::Shares::Momentum;
our $VERSION = 0.02;
use strict;
use warnings;

package Finance::Shares::Sample;
use Carp;
use Finance::Shares::Sample 0.12 qw(%period %function %functype);

$function{momentum} = \&momentum;
$function{ratio}    = \&ratio;
$function{gradient} = \&gradient;

$functype{momentum} = 'm';
$functype{ratio}    = 'm';
$functype{gradient} = 'm';
    
=head1 NAME

Finance::Shares::Momentum - functions dealing with rates of change

=head1 SYNOPSIS

    use Finance::Shares::Sample;
    use Finance::Shares::Momentum;

    my $s = new Finance::Shares::Sample(...);

    my $id1 = $s->momentum(
	graph  => 'prices',
	line   => 'close',
	period => 10,
	strict => 1,
	scaled => 1,
	shown  => 1,
	style  => {...}, # PostScript::Graph::Style
	key    => 'My Momentum Line',
    );
    my $id2 = $s->ratio(...);
    my $id3 = $s->gradient(...);
    
=head1 DESCRIPTION

This package provides additional methods for L<Finance::Shares::Sample> objects.  The functions analyse how
another line changes over time. 
Once a line has been constructed it may be referred to by a text identifier returned by the function.
The functions may also be referred to by their text names in a model specification:

    momentum
    ratio
    gradient

They all take the same parameters in hash key/value format and produce lines on the B<cycles> chart.
All of these keys are optional.

=over 8

=item graph

A string indicating the graph for display: one of prices, volumes, cycles or signals.  (Default: 'prices')

=item line

A string indicating the data/function to be analysed - normally the closing prices.  (Default: 'close')

=item period

The number of readings used in the analysis.  The actual time spanned depends on how the sample
was configured.

=item strict

Where appropriate, setting this to 0 might produce a better looking line by including some (possibly dubious)
guesses.  Set as 1 to ensure the line is accurate and reliable.

=item scaled

Set this to 1 to make comparison easier.  It ensures the values all lie within +/- 100.  Particularly useful for
C<ratio> which normally produces values of +/-1.

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

sub momentum {
    my $s = shift;
    croak "No Finance::Shares::Sample object" unless ref($s) eq 'Finance::Shares::Sample';
    my %a = (
	strict	=> 0,
	shown	=> 1,
	scaled  => 1,
	graph	=> 'prices',
	line	=> 'close',
	period	=> 5,
	style	=> undef,
	key	=> undef,
	@_);
    
    my $base = $s->{lines}{$a{graph}}{$a{line}};
    croak "No $a{graph} line '$a{line}'" unless $base;
    my $id = line_id('momentum', $a{period}, $a{line});
    my $dtype = $s->dates_by();
    my $key = $a{key} ? $a{key} : "$a{period} $period{$dtype} momentum" . ($base->{key} ? " of $base->{key}" : '');

    my $data = $s->calc_momentum($a{strict}, $base, $a{period});
    $s->scale($data) if $a{scaled};

    $s->add_line( 'cycles', $id, $data, $key, $a{style}, $a{shown} );
    return $id;
}

=head2 momentum

Movement is calculated by subtracting the value C<period> days/weeks/months ago.

=cut

sub ratio {
    my $s = shift;
    croak "No Finance::Shares::Sample object" unless ref($s) eq 'Finance::Shares::Sample';
    my %a = (
	strict	=> 0,
	shown	=> 1,
	scaled  => 1,
	graph	=> 'prices',
	line	=> 'close',
	period	=> 5,
	style	=> undef,
	key	=> undef,
	@_);
    
    my $base = $s->{lines}{$a{graph}}{$a{line}};
    croak "No $a{graph} line '$a{line}'" unless $base;
    my $id = line_id('ratio', $a{period}, $a{line});
    my $dtype = $s->dates_by();
    my $key = $a{key} ? $a{key} : "$a{period} $period{$dtype} ratio" . ($base->{key} ? " of $base->{key}" : '');

    my $data = $s->calc_ratio($a{strict}, $base, $a{period});
    $s->scale($data) if $a{scaled};

    $s->add_line( 'cycles', $id, $data, $key, $a{style}, $a{shown} );
    return $id;
 }

=head2 ratio

This calculates the rate of change by dividing the current value with a correspnding one C<period>
days/weeks/months previously.

C<strict> centers the line around 1, without this it centers around 0.  C<scaled> should probably be used.

=cut

sub gradient {
    my $s = shift;
    croak "No Finance::Shares::Sample object" unless ref($s) eq 'Finance::Shares::Sample';
    my %a = (
	strict	=> 0,
	shown	=> 1,
	scaled  => 1,
	graph	=> 'prices',
	line	=> 'close',
	period	=> 10,
	style	=> undef,
	key	=> undef,
	@_);
    
    my $base = $s->{lines}{$a{graph}}{$a{line}};
    croak "No $a{graph} line '$a{line}'" unless $base;
    my $id = line_id('gradient', $a{period}, $a{line});
    my $dtype = $s->dates_by();
    my $key = $a{key} ? $a{key} : "$a{period} $period{$dtype} gradient" . ($base->{key} ? " of $base->{key}" : '');

    my $data = $s->calc_gradient($a{strict}, $base, $a{period});
    $s->scale($data) if $a{scaled};

    $s->add_line( 'cycles', $id, $data, $key, $a{style}, $a{shown} );
    return $id;
}

=head2 gradient

This is an attempt to provide a function which differentiates, smoothing out abberations as it goes.  

A C<period> of 1 just produces the slope of the line to the next point.  Larger values, however, take a wider
spread of neighbours into account.  E.g. a 10 day gradient will calculate each gradient from the weighted average
of the differences from the previous 5 and subsiquent 5 days, where they exist.

=cut
 
sub calc_momentum {
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
    my $first = $start;
    my $last = $end > $start + $period ? $start + $period : $end;
    my $prev;
    for (my $i = $first; $i < $last; $i++) {
	$points{$keys[$i]} = $values[$i] - $prev if defined $values[$i] and defined $prev and not $strict;
	$prev = $values[$i] unless defined $prev;
    }
    
    for (my $i = $last; $i <= $end; $i++) {
	if ($strict) {
	    $prev = $values[$i-$period];
	} else {
	    $prev = $values[$i-$period] if defined $values[$i-$period];
	}
	$points{$keys[$i]} = $values[$i] - $prev if defined $values[$i] and defined $prev;
    }

    return \%points;
}
# Internal method called by momentum

sub calc_ratio {
    my ($s, $strict, $hash, $period) = @_;

    my (@keys, @values);
    my $data = $hash->{data};
    foreach my $k (sort keys %$data ) {
	my $v = $data->{$k};
	push @keys, $k;
	push @values, $v;
    }
    
    my %points;
    for (my $i = $period; $i <= $#values; $i++) {
	next unless (defined $values[$i-$period] and defined $values[$i]);
	my $prev = $values[$i-$period];
	my $v = $strict ? $values[$i]/$prev : $values[$i]/$prev - 1;
	$points{$keys[$i]} = $v;
    }

    return \%points;
}
# Internal method called by rate_of_change
#    open(TEST, '>', 'temp');
#	printf TEST 'i=%2d %s = %6.2f  prev=%6.2f  v=%6.2f %s', $i, $keys[$i], $values[$i], $prev, $v, "\n";
#    close TEST;

sub calc_gradient {
    my ($s, $strict, $hash, $period) = @_;

    my (@keys, @values);
    my $data = $hash->{data};
    foreach my $k (sort keys %$data ) {
	my $v = $data->{$k};
	push @keys, $k;
	push @values, $v;
    }
    my %points;
    my $end   = $#values;
    my $half  = $period/2;
    my $nhi   = int($period/2);
    my $nlo   = $nhi - $period;
    my $wmax  = -$nlo;
    my $first = $strict ? -$nlo : 0;
    my $last  = $strict ? $end - $nhi : $end;
    for (my $p = $first; $p <= $last; $p++) {
	next unless defined $values[$p];
	my $tdy = 0;
	my $twt = 0;
	foreach my $n ($nlo .. $nhi) {
	    next unless $n;
	    my $weight = $wmax - abs($n) + 1;
	    my $p1 = $p + $n;
	    if ($p1 >= 0 and $p1 <= $end and defined $values[$p1]) {
		my $dy = ($n > 0) ? $values[$p1] - $values[$p] : $values[$p] - $values[$p1];
		$tdy += $weight * $dy;
		$twt += $weight;
	    }
	}
	$points{$keys[$p]} = $tdy/$twt if $twt;
    }
    
    return \%points;
}
# Internal method called by gradient
#    open(TEST, '>', 'temp');
#	print TEST "p=$p $keys[$p] = $values[$p]\n";
#	    print TEST "  n=$n weight=$weight p1=$p1 (end=$end)\n";
#		print TEST "  tdy=$tdy twt=$twt dy=$dy p1=$values[$p1] p=$values[$p]\n";
#	print TEST "points{$keys[$p]} = ",$tdy/$twt,"\n\n" if $twt;
#    close TEST;

sub scale {
    my ($s, $data) = @_;
    my $sc = $s->{cycles};

    my $max = 0;
    foreach my $v (values %$data) {
	next unless defined $v;
	my $t = ($v >= 0) ? $v : -$v;
	$max = $t if $t > $max;
    }

    if ($max) {
	my $factor = 100/$max;
	while( my ($k, $v) = each %$data ) {
	    $data->{$k} = $v * $factor if defined $v;
	    $data->{$k} =  100 if $data->{$k} >  100; 
	    $data->{$k} = -100 if $data->{$k} < -100; 
	}
    }

    my $min = $s->{cycles}{min};
    $s->{cycles}{min} = -100 unless defined($min) and $min < -100;
    $max = $s->{cycles}{max};
    $s->{cycles}{max} =  100 unless defined($max) and $max >  100;
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
