package Finance::Shares::Bands;
our $VERSION = 0.12;

package Finance::Shares::Sample;
use strict;
use warnings;
use Finance::Shares::Sample 0.11 qw(%period %line line_id);
use Carp;

$line{env_e}   = \&envelope;
$line{boll_b}  = \&bollinger_band;
$line{chan_c}  = \&channel;

=head1 NAME

Finance::Shares::Bands - High and low boundaries

=head1 SYNOPSIS

    use Finance::Shares::Sample;
    use Finance::Shares::Bands;

    $s = new Finance::Shares::Sample(...);

    ($high, $low) = $s->envelope(percent => 4);
    ($high, $low) = $s->bollinger_bands();
    ($high, $low) = $s->channel(
	graph  => 'prices',
	line   => 'close',
	period => 20,
	style  => {...},
	shown  => 1,
	key    => '20 day channel',
    );
    
=head1 DESCRIPTION

This package provides additional methods for L<Finance::Shares::Sample> objects.  The functions provide two boundary
lines, above and below another source line.  Once the lines have been constructed they may
be referred to by text identifiers returned by the function.

They all take parameters in hash key/value format.

=cut

sub envelope {
    my $s = shift;
    croak "No Finance::Shares::Sample object" unless ref($s) eq 'Finance::Shares::Sample';
    my %a = (
	shown	=> 1,
	graph	=> 'prices',
	line	=> 'close',
	percent	=> 3,
	style	=> undef,
	key	=> undef,
	@_);
    
    my $base = $s->{lines}{$a{graph}}{$a{line}};
    croak "No $a{graph} line with id $a{line}" unless $base;
    
    ## generate lines
    my (@keys, @values);
    my $data = $base->{data};
    foreach my $k (sort keys %$data ) {
	my $v = $data->{$k};
	push @keys, $k;
	push @values, $v;
    }
    
    my (%low, %high);
    foreach my $i (0 .. $#values) {
	my $date = $keys[$i];
	my $val  = $values[$i];
	if (defined $val) {
	    my $diff = $val * $a{percent}/100;
	    $low{$date}  = $val - $diff;
	    $high{$date} = $val + $diff;
	}
    }

    ## add lines to graphs
    my $dtype = $s->dates_by();
    my ($key_low, $key_high);
    my $key = $base->{key};
    $key = '' unless $key;
    if (ref($a{style}) eq 'PostScript::Graph::Style') {
	$key_low  = $key_high = $a{key} ? $a{key} : $a{percent} . "% around $key";
    } else {
	if ($a{key}) {
	    $key_low  = $a{key} . " low";
	    $key_high = $a{key} . " high";
	} else {
	    $key_low  = $a{percent} . "% below $key";
	    $key_high = $a{percent} . "% above $key";
	}
    }
    my $low_id = line_id('env_lo', $a{percent}, $a{line});
    my $high_id = line_id('env_hi', $a{percent}, $a{line});
    $s->add_line( $a{graph}, $low_id,  \%low,  $key_low,  $a{style}, $a{shown} );
    $s->add_line( $a{graph}, $high_id, \%high, $key_high, $a{style}, $a{shown} );

    return ($high_id, $low_id);
}

=head2 envelope
    
Add lines C<pc> percent above and below the main data line.
All of the following keys are optional.

=over 8

=item graph

A string indicating the graph for display: one of prices, volumes, cycles or signals.  (Default: 'prices')

=item line

A string indicating the central data/function.  (Default: 'close')

=item percent

The lines are generated this percentage above and below the guide line.  (Default: 3)

=item style

An optional hash ref holding settings suitable for the PostScript::Graph::Style object used when drawing the line.
By default lines and points are plotted, with each line in a slightly different style.  (Default: undef)

If C<style> is a hash ref, a seperate Style is used for each line.  To get both lines to have the same appearance,
pass a PostScript::Graph::Style reference.

=item shown

A flag controlling whether the function is graphed.  0 to not show it, 1 to add the lines to the C<graph>
indicated.  (Default: 1)

=back

The main reason for generating an envelope around a line is to identify a range of readings that are acceptable.
Buy or sell signals may be generated if prices move outside this band.

Like all functions, this returns the line identifiers.  However, there are two, an upper and a lower bound, so
they are returned as a list:

    (high_id, low_id)

=cut

sub bollinger_band {
   my $s = shift;
    croak "No Finance::Shares::Sample object" unless ref($s) eq 'Finance::Shares::Sample';
    my %a = (
	strict	=> 1,
	shown	=> 1,
	graph	=> 'prices',
	line	=> 'close',
	period	=> 20,
	style	=> undef,
	key	=> undef,
	@_);
    $a{period} = 20 if $a{strict} or not $a{period};
    
    my $base = $s->{lines}{$a{graph}}{$a{line}};
    croak "No $a{graph} line with id $a{line}" unless $base;
    
    ## generate lines
    my (@keys, @values);
    my $data = $base->{data};
    foreach my $k (sort keys %$data ) {
	my $v = $data->{$k};
	push @keys, $k;
	push @values, $v;
    }
    
    my $scale = 2;
    my (%low, %high); 
    foreach my $i (0 .. $#values) {
	my $date = $keys[$i];
	my $val  = $values[$i];
	if (defined $val) { 
	    my $diff = bollinger_single($a{strict}, \@keys, \@values, $a{period}, $i); 
	    if (defined $diff) { 
		$diff *= $scale;
		$low{$date}  = $val - $diff;
		$high{$date} = $val + $diff;
	    }
	}
    }

    ## add lines to graphs
    my $dtype = $s->dates_by();
    my ($key_low, $key_high);
    my $base_key = $base->{key};
    if (ref($a{style}) eq 'PostScript::Graph::Style') {
	$key_low  = $key_high = $a{key} ? $a{key} : "Bollinger band" . ($base_key ? " around $base_key" : '');
    } else {
	if ($a{key}) {
	    $key_low  = $a{key} . " low";
	    $key_high = $a{key} . " high";
	} else {
	    $key_low  = "Bollinger band" . ($base_key ? " below $base_key" : '');
	    $key_high = "Bollinger band" . ($base_key ? " above $base_key" : '');
	}
    }
    my $low_id = line_id('boll_lo', $a{line});
    my $high_id = line_id('boll_hi', $a{line});
    $s->add_line( $a{graph}, $low_id,  \%low,  $key_low,  $a{style}, $a{shown} );
    $s->add_line( $a{graph}, $high_id, \%high, $key_high, $a{style}, $a{shown} );

    return ($high_id, $low_id);
}

=head2 bollinger_bands
    
A Bollinger band comprising upper and lower boundary lines is placed around a main data line.
All of the following keys are optional.

=over 8

=item graph

A string indicating the graph for display: one of prices, volumes, cycles or signals.  (Default: 'prices')

=item line

A string indicating the central data/function.  (Default: 'close')

=item period

The number of days, weeks or months being sampled.  If 'strict' is set, this will always be 20.  It controls the
length of the sample used to calculate the 2 standard deviation above and below, so making it too small will give
spurious results.

=item style

An optional hash ref holding settings suitable for the PostScript::Graph::Style object used when drawing the line.
By default lines and points are plotted, with each line in a slightly different style.  (Default: undef)

If C<style> is a hash ref, a seperate Style is used for each line.  To get both lines to have the same appearance,
pass a PostScript::Graph::Style reference.

=item strict

Normally 1, where the period will be 20 quotes.  Setting this to 0 relaxes this rule, allowing C<period> to be
set.  (Default: 1)

=item shown

A flag controlling whether the function is graphed.  0 to not show it, 1 to add the lines to the C<graph>
indicated.  (Default: 1)

=back

A Bollinger band is bounded by lines 2 standard deviations above and below the main data line.  The band is
sensitive to volatility, narrowing if the data is stable and widening as the variance increases.  

Bollinger bands are always calculated on 20 days, weeks or months.  This provides a good sample to reliably
measure around 95% of the closing prices (the default C<line> id).  Buy or sell signals may be generated if prices
move outside this.  

Even without C<strict>, there is always a lead-in period where values are undefined.

Like all functions, this returns the line identifiers.  However, there are two, an upper and a lower bound, so
they are returned as a list:

    (high_id, low_id)

=cut


sub bollinger_single {
    my ($strict, $keys, $values, $period, $day) = @_;
    
    my ($ex2, $total) = (0, 0);
    my $base = $day - $period;
    my $count = 0;
    for (my $i = $period; $i; $i--) {
	my $d = $base + $i;
	return undef if ($d < 0);
	my $date = $keys->[$i];
	my $val  = $values->[$i];
	return undef unless (defined $val);
	$total += $val;
	$count++;
	$ex2 += $val * $val;
    }
    return undef if ($strict and $count < 20);
    return undef unless $count;
    my $mean = $total/$count;
    my $sd = sqrt($ex2/$count - $mean * $mean);
    return $sd;
}
# $day is index into dates array

sub channel {
    my $s = shift;
    croak "No Finance::Shares::Sample object" unless ref($s) eq 'Finance::Shares::Sample';
    my %a = (
	shown	=> 1,
	graph	=> 'prices',
	line	=> 'close',
	period	=> 10,
	style	=> undef,
	id	=> undef,
	key	=> undef,
	@_);
    
    my $base = $s->{lines}{$a{graph}}{$a{line}};
    croak "No $a{graph} line with id $a{line}" unless $base;
     
    ## generate lines
    my (@keys, @values);
    my $data = $base->{data};
    foreach my $k (sort keys %$data ) {
	my $v = $data->{$k};
	push @keys, $k;
	push @values, $v;
    }
     
    my (%low, %high);
    foreach my $i (0 .. $#values) {
	my $date = $keys[$i];
	my $val  = $values[$i];
	if (defined $val) {
	    my ($min, $max) = channel_single(\@values, $a{period}, $i);
	    $low{$date}  = $min;
	    $high{$date} = $max;
	}
    }

    ## add lines to graphs
    my $dtype = $s->dates_by();
    my ($key_low, $key_high);
    my $period = $period{$dtype};
    my $base_key = $base->{key};
    if (ref($a{style}) eq 'PostScript::Graph::Style') {
	$key_low  = $key_high = $a{key} ? $a{key} : "$a{period} $period channel" . ($base_key ? " for $base_key" : '');
    } else {
	if ($a{key}) {
	    $key_low  = $a{key} . " low";
	    $key_high = $a{key} . " high";
	} else {
	    $key_low  = "$a{period} $period low" . ($base_key ? " for $base_key" : '');
	    $key_high = "$a{period} $period high" . ($base_key ? " for $base_key" : '');
	}
    }
    my $low_id = line_id('chan_lo', $a{period}, $a{line});
    my $high_id = line_id('chan_hi', $a{period}, $a{line});
    $s->add_line( $a{graph}, $low_id,  \%low,  $key_low,  $a{style}, $a{shown} );
    $s->add_line( $a{graph}, $high_id, \%high, $key_high, $a{style}, $a{shown} );

    return ($high_id, $low_id);
}

=head2 channel

This is the function which will give functions like 52 week highs or the lowest price in the last 30 days.
All of the following keys are optional.

=over 8

=item graph

A string indicating the graph for display: one of prices, volumes, cycles or signals.  (Default: 'prices')

=item line

A string indicating the central data/function.  (Default: 'close')

=item period

The number of days, weeks or months over which the highest and lowest values are recorded.  (Default: 10)

=item style

An optional hash ref holding settings suitable for the PostScript::Graph::Style object used when drawing the line.
By default lines and points are plotted, with each line in a slightly different style.  (Default: undef)

If C<style> is a hash ref, a seperate Style is used for each line.  To get both lines to have the same appearance,
pass a PostScript::Graph::Style reference.

=item shown

A flag controlling whether the function is graphed.  0 to not show it, 1 to add the lines to the C<graph>
indicated.  (Default: 1)

=back

This function adds lines above and below the main data line which show the highest and lowest points in the
specified period.

The main reason for generating a channel around a line is to identify a range of readings that are acceptable.
Buy or sell signals may be generated if prices move outside this band.

Like all functions, this returns the line identifiers.  However, there are two, an upper and a lower bound, so
they are returned as a list:

    (high_id, low_id)

=cut

sub channel_single {
    my ($values, $period, $day) = @_;
    
    my $max = 0;
    my $min = 10 ** 20;
    my $base = $day - $period;
    for (my $i = $period; $i > 0; $i--) {
	my $d = $base + $i;
	if ($d >= 0) {
	    my $val  = $values->[$d];
	    if (defined $val) {
		$max = $val if $val > $max;
		$min = $val if $val < $min;
	    }
	}
    }

    return ($min, $max);
}
# $day is index into dates array

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
