package Finance::Shares::Momentum;
our $VERSION = 0.06;
use strict;
use warnings;

package Finance::Shares::Sample;
use Finance::Shares::Sample 0.12 qw(call_function %period %function %functype);
use Finance::Shares::Averages 0.12;

#use TestFuncs 'show_deep';

$function{momentum}  = \&momentum;
$function{ratio}     = \&ratio;
$function{gradient}  = \&gradient;
$function{rising}    = \&rising;
$function{falling}   = \&falling;
$function{oversold}  = \&oversold;
$function{undersold} = \&undersold;
$function{on_balance_volume} = \&on_balance_volume;
$function{direction} = \&direction;
$function{extend}    = \&extend;
$function{mom}   = \&momentum;
$function{roc}   = \&ratio;
$function{grad}  = \&gradient;
$function{rise}  = \&rising;
$function{fall}  = \&falling;
$function{over}  = \&oversold;
$function{under} = \&undersold;
$function{obv}   = \&on_balance_volume;
$function{adx}   = \&direction;
$function{ext}   = \&extend;

$functype{momentum}  = 'm';
$functype{ratio}     = 'm';
$functype{gradient}  = 'm';
$functype{rising}    = 'n';
$functype{falling}   = 'n';
$functype{oversold}  = 'n';
$functype{undersold} = 'n';
$functype{on_balance_volume} = 'o';
$functype{mom}   = 'm';
$functype{roc}   = 'm';
$functype{grad}  = 'm';
$functype{rise}  = 'n';
$functype{fall}  = 'n';
$functype{over}  = 'n';
$functype{under} = 'n';
$functype{obv}   = 'o';
$functype{adx}   = 'o';
    
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
	strict => 0,
	scaled => 1,
	shown  => 1,
	style  => {...}, # PostScript::Graph::Style
	key    => 'My Momentum Line',
    );
    my $id2 = $s->ratio(...);
    my $id3 = $s->gradient(...);
    
    my $id4 = $s->rising(
	...
	style    => {...}, # PostScript::Graph::Style
	key      => 'Rising Trends',
	weight   => 50,
	decay    => 0.66,
	ramp     => 0,
	cutoff   => {...}, # PostScript::Graph::Style
	gradient => {...}, # PostScript::Graph::Style
	smallest => 10,
    );
    my $id5 = $s->falling(...);

    my $id6 = $s->oversold(
	...
	gradient => {...}, # PostScript::Graph::Style
	sd => 2.5,
    );
    my $id7 = $s->undersold(...);
    
=head1 DESCRIPTION

This package provides additional methods for L<Finance::Shares::Sample> objects.  Some functions analyse how
another line changes over time and produce lines on the B<cycles> graph.   Others are pseudo-tests producing
digital output on the B<tests> graph, although they don't trigger signals (use the B<test> test for that, see
L<Finance::Shares::Models/Tests>).

Once a line has been constructed it may be referred to by a text identifier returned by the function.
The functions may also be referred to by their text names in a model specification (short or full version):

    mom	    momentum
    roc	    ratio		(Rate of Change)
    grad    gradient
    obv	    on_balance_volume
    adx	    direction
    
    rise    rising
    fall    falling
    over    oversold
    under   undersold
    ext	    extend

=head2 Common options

They all take the following parameters in hash key/value format.  All of these keys are optional.

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
guesses.  Set as 1 to ensure the line is accurate and reliable.  (Default: 1)

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

=head2 Pseudo-test options

In addition, the pseudo-tests C<rising>, C<falling>, C<oversold> and C<undersold> also recognize these keys.

=over 8

=item smallest

[C<rising> and C<falling> only.]  This is the smallest daily change that will be considered.  For example,

    $s->falling(
	line     => 'close',
	period   => 10,
	smallest => 5,
    );

This will only produce 'true' if the closing price was 5p or more lower than the day before, according to the 10
day smoothed gradient.

=item sd

[C<oversold> and C<undersold> only.]  Short for standard deviation, this defines the point beyond which stock is
deemed oversold or undersold.  The following table gives some idea how standard deviation relates to the number of
quotes within the normal area or in the under/oversold region.

    sd	    within  above or below
    3.00    99.74%	 0.13%
    2.58    99%		 0.5%
    2.33    98%		 1%
    2.06    96%		 2%
    2.00    95.46%	 2.27%
    1.65    90%		 5%
    1.29    80%		10%
    1.15    75%		12.5%
    1.00    68.26%	15.87%
    0.85    60%		20%
    0.68    50%		25%

=item weight

How important the test should appear.  Most tests implement this as the height of the results line.

=item decay

If the condition is met over a continuous period, the results line can be made to decay.  This factor is
multiplied by the previous line value, so 0.95 would produce a slow decay while 0 signals only the first date in
the period.

=item ramp

An alternative method for conditioning the test line.  This amount is added to the test value with each
period.

=item gradient

Determine whether, and how, the gradient line will be shown. It can be '0' for hide or '1' for show but the most
useful is a PostScript::Graph::Style object or a hash ref holding style settings.

=item cutoff

Determine whether, and how, the boundary line will be shown. It can be '0' for hide or '1' for show but the most
useful is a PostScript::Graph::Style object or a hash ref holding style settings.

=head2 Example script

Sometimes it is useful to see how the parts fit within the whole.  Here is a fairly minimal script that marks
suitable buy points on a chart.  Signals are triggered when the volume rises in an undersold period.  Or more
explicitly: 

    if
	the sample has been undersold
	    (prices lower than 1 std dev)
	in the last 5 days
    and
	the 10 day 'on balance volume'
	is rising
    then
	a buy signal highlights the low price

The Sample needs a MySQL object to provide the quotes, so that must be constucted first.  Both Chart and Model
need the Sample in turn, and before a signal is used, the Model needs to know all about it.  We are then in
a position to build all the functions (all from this module as it happens).  Finally the test produces the signals
and the chart is saved as 'output.ps'.
	
    #!/usr/bin/perl
    use strict;
    use warnings;
    use Finance::Shares::MySQL;
    use Finance::Shares::Sample;
    use Finance::Shares::Momentum;
    use Finance::Shares::Model;
    use Finance::Shares::Chart;

    my $sql = new Finance::Shares::MySQL(
	    user	 => 'test',
	    password => 'test',
	    database => 'test',
	    mode     => 'offline',
	);

    my $sample = new Finance::Shares::Sample(
	    source	 => $sql,
	    symbol	 => 'AV.L',
	    start_date => '2003-01-01',
	    end_date => '2003-06-30',
	);

    my $chart = new Finance::Shares::Chart(
	    sample   => $sample,
	);
	
    my $model = new Finance::Shares::Model;
    $model->add_sample($sample);
    $model->add_signal('buysig', 'mark_buy', undef, {
	    graph   => 'prices',
	    line    => 'low',
	}); 

    my $usold = $sample->undersold(
	    sd      => 1,
	    shown   => 0,	
	);

    my $usold_ex = $sample->extend(
	    graph   => 'tests',
	    line    => $usold,
	    period  => 5,
	    key     => 'undersold (ext)',
	    weight  => 75,
	);

    my $obv = $sample->on_balance_volume(
	    period  => 10,
	    key     => 'obv',
	);
	
    my $vup = $sample->rising(
	    graph   => 'cycles',
	    line    => $obv,
	    key     => 'rising OBV',
	    weight  => 50,
	);

    my $both = $model->test(
	    graph1  => 'tests',
	    line1   => $usold_ex,
	    graph2  => 'tests',
	    line2   => $vup,
	    test    => 'and',
	    signals => ['buysig'],
	    shown   => 1,
	    key     => 'oversold & rising vol',
	);

    $chart->output('example');

Key strings were declared throughout to stop too much space being wasted by the Key panels.  The weights have just
been given to make the tests graph clearer.  See the tests for examples of how to make the chart look better using
L<PostScript::File>, L<PostScript::Graph::Style> and L<Finance::Shares::Chart> options.

This test can be found in fs_model format in the distribution as F<models/momentum_ex>.  The following command
will apply this model to all the stocks listed in the file F<stock/FTSE-retail>.

    fs_model -m models/momentum -s -c stock/FTSE-retail

The resulting PostScript file F<FTSE-retail.ps> has a page showing how each stock fared under the test.

=back

=head1 MOMENTUM METHODS

=cut

sub momentum {
    my $s = shift;
    die "No Finance::Shares::Sample object\n" unless ref($s) eq 'Finance::Shares::Sample';
    my %a = (
	strict	=> 1,
	shown	=> 1,
	scaled  => 1,
	graph	=> 'prices',
	line	=> 'close',
	period	=> 5,
	style	=> undef,
	key	=> undef,
	@_);
    
    my $base = $s->{lines}{$a{graph}}{$a{line}};
    die "No $a{graph} line '$a{line}'\n" unless $base;
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
    die "No Finance::Shares::Sample object\n" unless ref($s) eq 'Finance::Shares::Sample';
    my %a = (
	strict	=> 1,
	shown	=> 1,
	scaled  => 1,
	graph	=> 'prices',
	line	=> 'close',
	period	=> 5,
	style	=> undef,
	key	=> undef,
	@_);
    
    my $base = $s->{lines}{$a{graph}}{$a{line}};
    die "No $a{graph} line '$a{line}'\n" unless $base;
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

The line centers around 1 normally, but can be made to center around zero by setting C<strict> to 0.  C<scaled>
should probably be used.

=cut

sub gradient {
    my $s = shift;
    die "No Finance::Shares::Sample object\n" unless ref($s) eq 'Finance::Shares::Sample';
    my %a = (
	strict	=> 1,
	shown	=> 1,
	scaled  => 1,
	graph	=> 'prices',
	line	=> 'close',
	period	=> 10,
	style	=> undef,
	key	=> undef,
	@_);
    
    my $base = $s->{lines}{$a{graph}}{$a{line}};
    die "No $a{graph} line '$a{line}'\n" unless $base;
    my $id = line_id('gradient', $a{period}, $a{line});
    my $dtype = $s->dates_by();
    my $key = $a{key} ? $a{key} : "$a{period} $period{$dtype} gradient" . ($base->{key} ? " of $base->{key}" : '');

    my $data = $s->calc_gradient($a{strict}, $base, $a{period});
    $s->scale($data) if $a{scaled};

    $s->add_line( 'cycles', $id, $data, $key, $a{style}, $a{shown} );
    return $id;
}

=head2 gradient

This is an attempt to provide a function which performs differentiation, smoothing out abberations as it goes.  

A C<period> of 1 just produces the slope of the line to the next point.  Larger values, however, take a wider
spread of neighbours into account.  E.g. a 10 day gradient will calculate each gradient from the weighted average
of the differences from the previous 5 and subsiquent 5 days, where they exist.

=cut

sub on_balance_volume {
    my $s = shift;
    die "No Finance::Shares::Sample object\n" unless ref($s) eq 'Finance::Shares::Sample';
    my $a = { @_ };
    $a->{strict} = 1 unless defined $a->{strict};
    $a->{shown}  = 1 unless defined $a->{shown};
    $a->{scaled} = 1 unless defined $a->{scaled};
    $a->{period} = 1 unless defined $a->{period};
    #$a->{style} = undef
    #$a->{key}   = undef
    my $base = $s->{lines}{volumes}{volume};
    my $vdata = $base->{data};
    my $gdata = ensure_gradient($s, {
	graph    => 'prices',
	line     => 'close',
	period   => $a->{period},
	scaled   => 0,
	gradfn   => 'gradient',
	gradient => $a->{gradient},
	strict   => $a->{strict},
    });
 
    my $res = {};
    my $level = 0;
    foreach my $date (sort keys %$gdata) {
	my $volume = $vdata->{$date};
	my $gd = $gdata->{$date};
	if (defined $volume and defined $gd) {
	    my $sgn = ($gd < 0) ? -1 : (($gd == 0) ? 0 : 1);
	    $level += $sgn * $volume;
	    $res->{$date} = $level;
	}
    }

    my $id = line_id('on_balance', 'volume');
    my $key = $a->{key} ? $a->{key} : 'on balance volume';
    $s->scale($res) if $a->{scaled};

    $s->add_line( 'cycles', $id, $res, $key, $a->{style}, $a->{shown} );
    
    return $id;
}

=head2 on_balance_volume

This function produces a line on the B<cycles> graph, showing how the volume varies.  It presents a running total,
adding the days volume if the price closed higher than the previous date or subtracting it if the price closed
lower.

Being a specialized function, there are fewer options. See L</DESCRIPTION> for explanation of the keys available:

   shown	scaled
   style	key
   strict	gradient

The direction of movement is more significant than the raw numbers.  So it is usually scaled or passed to
B<rising> or B<falling>.
   
=cut

sub direction {
    my $s = shift;
    die "No Finance::Shares::Sample object\n" unless ref($s) eq 'Finance::Shares::Sample';
    my $a = { @_ };
    $a->{strict}  = 1	  unless defined $a->{strict};
    $a->{shown}   = 1	  unless defined $a->{shown};
    $a->{scaled}  = 1	  unless defined $a->{scaled};
    $a->{dir}     = 0	  unless defined $a->{dir};
    $a->{period}  = 0     unless defined $a->{period};
    $a->{average} = 'avg' unless defined $a->{average};
    #$a->{style} = undef
    #$a->{key}   = undef
    
    my $dhigh  = $s->{lines}{prices}{high}{data};
    my $dlow   = $s->{lines}{prices}{low}{data};
    my $dclose = $s->{lines}{prices}{close}{data};
    
    my $res = {};
    my $level = 0;
    my $pdate;
    foreach my $date (sort keys %$dclose) {
	if (defined $pdate) {
	    my $pclose = $dclose->{$pdate};
	    my $hi_pc  = $dhigh->{$date} - $pclose;
	    my $pc_lo  = $pclose - $dlow->{$date};
	    if ($a->{dir} > 0) {
		$level = ($hi_pc > $pc_lo) ? 1 : 0;
	    } elsif ($a->{dir} < 0) {
		$level = ($hi_pc >= $pc_lo) ? 0 : -1;
	    } else {
		$level = ($hi_pc > $pc_lo) ? 1 : -1;
	    }
	    $res->{$date} = $level;
	}
	$pdate = $date;
    }

    my $id = line_id('direction', $a->{dir});
    my $key;
    if ($a->{key}) {
	$key = $a->{key};
    } elsif ($a->{dir} > 0) {
	$key .= 'upward direction';
    } elsif ($a->{dir} < 0) {
	$key .= 'downward direction';
    } else {
	$key .= 'average direction';
    }
    $s->scale($res) if $a->{scaled};

    if ($a->{period}) {
	my $dtype = $s->dates_by();
	my $line = $s->add_line( 'cycles', $id, $res, $key, undef, 0 );
	$id = call_function( \%function, $a->{average}, $s, 
	    graph => 'cycles',
	    line  => $id,
	    period => $a->{period},
	    strict => $a->{strict},
	    shown  => $a->{shown},
	    style  => $a->{style},
	    key    => "$a->{period} $period{$dtype} $key",
	);
    } else {
	$s->add_line( 'cycles', $id, $res, $key, $a->{style}, $a->{shown} );
    }
    return $id;
}

=head2 direction

This is really three function in one.  The lines are drawn on the B<cycles> graph, indicating the direction prices
are moving.  Option keys include:

=over 8

=item dir

Standing for 'direction', this determines the type of line produced.  (Default: 0)

    +1	Upward movement
     0	Average of up and down
    -1	Downward movement

=item period

If 0, the direction line is unsmoothed.  Otherwise a moving average of this period is used for smoothing.
(Default: 0)

=item average

This should be the name (short or long) of a moving average function.  It should be one of the following.
(Default: 'avg')

   avg	simple_average
   wgt	weighted_average
   exp	exponential_average
    
=back

The following keys are also supported.  See L</DESCRIPTION> for details.

   shown	scaled
   style	key

=cut

=head1 PSEUDO-TEST METHODS

=cut
 
sub rising {
    my $s = shift;
    die "No Finance::Shares::Sample object\n" unless ref($s) eq 'Finance::Shares::Sample';
    my $a = test_args(@_);
    my $lb = $s->choose_line($a->{graph}, $a->{line}, 1);
    die "No $a->{graph} line with id '$a->{line}'\n" unless $lb;
    my $data = ensure_gradient( $s, $a );
    
    my $prev;
    my $level = $a->{min};
    my $cutoff = $a->{smallest};
    my $res = {};
    foreach my $date (sort keys %$data) {
	my $cond = ($data->{$date} > $cutoff);
	if (not defined($prev) or $cond != $prev) {
	    $level = $cond ? $a->{max} : $a->{min};
	} else {
	    $level = condition( $a, $level );
	}
	$res->{$date} = $level;
	$prev = $cond;
    }
   
    my $line_key  = $lb->{key} . ' is rising';
    my $level_key = 'rising cutoff at ' . sprintf('%.2f', $cutoff);
    my $id = create_lines($s, $a, $res, 'rising', $line_key, $level_key, $cutoff);
    return $id;
}

=head2 rising

A pseudo-test producing a true/false output on the tests graph depending on whether the gradient of the specified
line is sufficiently positive.

=cut

sub falling {
    my $s = shift;
    die "No Finance::Shares::Sample object\n" unless ref($s) eq 'Finance::Shares::Sample';
    my $a = test_args(@_);
    my $lb = $s->choose_line($a->{graph}, $a->{line}, 1);
    die "No $a->{graph} line with id '$a->{line}'\n" unless $lb;
    my $data = ensure_gradient( $s, $a );

    my $prev;
    my $level = $a->{min};
    my $cutoff = $a->{smallest} > 0 ? -$a->{smallest} : $a->{smallest};
    my $res = {};
    foreach my $date (sort keys %$data) {
	my $value = $data->{$date};
	my $cond = $value < $cutoff;
	if (not defined($prev) or $cond != $prev) {
	    $level = $cond ? $a->{max} : $a->{min};
	} else {
	    $level = condition( $a, $level );
	}
	$res->{$date} = $level;
	$prev = $cond;
    }
    
    my $line_key  = $lb->{key} . ' is falling';
    my $level_key = 'falling cutoff at ' . sprintf('%.2f', $cutoff);
    my $id = create_lines($s, $a, $res, 'falling', $line_key, $level_key, $cutoff);
    return $id;
}

=head2 falling

A pseudo-test producing a true/false output on the tests graph depending on whether the gradient of the specified
line is sufficiently negative.

=cut

sub oversold {
    my $s = shift;
    die "No Finance::Shares::Sample object\n" unless ref($s) eq 'Finance::Shares::Sample';
    my $a = test_args(@_);
    my $lb = $s->choose_line($a->{graph}, $a->{line}, 1);
    die "No $a->{graph} line with id '$a->{line}'\n" unless $lb;
    my $data = ensure_gradient( $s, $a );
    
    my $sum2 = 0;
    my $total = 0;
    my $count = 0;
    foreach my $v (values %$data) {
	next unless defined $v;
	$count++;
	$total += $v;
	$sum2  += $v*$v;
    }
    
    my $res = {};
    my $cutoff = $a->{min};
    if ($count) {
	my $mean = $total/$count;
	my $sd = sqrt( $sum2/$count - $mean*$mean );
	$cutoff = $mean + $a->{sd}*$sd;
	
	my $prev;
	my $level = $a->{min};
	foreach my $date (sort keys %$data) {
	    my $cond = $data->{$date} > $cutoff;
	    if (not defined($prev) or $cond != $prev) {
		$level = $cond ? $a->{max} : $a->{min};
	    } else {
		$level = condition( $a, $level );
	    }
	    $res->{$date} = $level;
	    $prev = $cond;
	}
    }
    
    my $line_key  = $a->{key} ? $a->{key} : $lb->{key} . ' is oversold';
    my $level_key = 'oversold cutoff at ' . sprintf('%.2f', $cutoff);
    my $id = create_lines($s, $a, $res, 'oversold', $line_key, $level_key, $cutoff);
    return $id;
}

=head2 oversold

A pseudo-test producing a true/false output on the tests graph depending on whether the gradient rises above
a certain level.  The level depends on the data sampled, so it is controlled using C<sd>. 

=cut

sub undersold {
    my $s = shift;
    die "No Finance::Shares::Sample object\n" unless ref($s) eq 'Finance::Shares::Sample';
    my $a = test_args(@_);
    my $lb = $s->choose_line($a->{graph}, $a->{line}, 1);
    die "No $a->{graph} line with id '$a->{line}'\n" unless $lb;
    my $data = ensure_gradient( $s, $a );

    my $sum2 = 0;
    my $total = 0;
    my $count = 0;
    foreach my $v (values %$data) {
	next unless defined $v;
	$count++;
	$total += $v;
	$sum2  += $v*$v;
    }
    
    my $res = {};
    my $cutoff = $a->{min};
    if ($count) {
	my $mean = $total/$count;
	my $sd = sqrt( $sum2/$count - $mean*$mean );
	$cutoff = $mean - $a->{sd}*$sd;
	
	my $prev;
	my $level = $a->{min};
	foreach my $date (sort keys %$data) {
	    my $cond = $data->{$date} < $cutoff;
	    if (not defined($prev) or $cond != $prev) {
		$level = $cond ? $a->{max} : $a->{min};
	    } else {
		$level = condition( $a, $level );
	    }
	    $res->{$date} = $level;
	    $prev = $cond;
	}
    }
    
    my $line_key  = $a->{key} ? $a->{key} : $lb->{key} . ' is undersold';
    my $level_key = 'undersold cutoff at ' . sprintf('%.2f', $cutoff);
    my $id = create_lines($s, $a, $res, 'undersold', $line_key, $level_key, $cutoff);
    return $id;
}

=head2 undersold

A pseudo-test producing a true/false output on the tests graph depending on whether the gradient falls below
a certain level.  The level depends on the data sampled, so it is controlled using C<sd>. 

=cut

sub extend {
    my $s = shift;
    die "No Finance::Shares::Sample object\n" unless ref($s) eq 'Finance::Shares::Sample';
    my $a = test_args(@_);
    my $base = $s->choose_line($a->{graph}, $a->{line}, 1);
    die "No $a->{graph} line with id '$a->{line}'\n" unless $base;

    my $data   = $base->{data};
    my $level  = $a->{min};
    my $cutoff = $a->{smallest};
    my $count  = 0;
    my $res    = {};
    foreach my $date (sort keys %$data) {
	if ($count) {
	    $count--;
	    $level = condition( $a, $level );
	} else {
	    my $cond = $data->{$date} > $cutoff;
	    if ($cond) {
		$level = $a->{max};
		$count = $a->{period};
	    } else {
		$level = $a->{min};
	    }
	}
	$res->{$date} = $level;
    }
 
    my $dtype = $s->dates_by();
    my $line_key = $a->{key} ? $a->{key} : "$a->{period} $period{$dtype} extension of $base->{key}";
    my $level_key = 'cutoff at ' . sprintf('%.2f', $cutoff);
    my $id = create_lines($s, $a, $res, 'extend', $line_key, $level_key, $cutoff);
    return $id;
}

=head2 extend

This produces a logic line on the tests graph like the other pseudo-tests, but unlike the others it doesn't really
test anything.  It provides a fixed period following some event on the line passed to it.  It is level triggered,
with the period beginning when the line moves above the value of C<smallest>.

Example

   
=cut

### SUPPORT METHODS

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

### SUPPORT FUNCTIONS

sub test_args {
    my $a = { @_ };

    $a->{strict} = 1	      unless defined $a->{strict};
    $a->{shown}  = 1	      unless defined $a->{shown};
    $a->{scaled} = 1	      unless defined $a->{scaled};
    $a->{graph}  = 'prices'   unless defined $a->{graph};
    $a->{line}   = 'close'    unless defined $a->{line};
    $a->{period} = 10	      unless defined $a->{period};
    #$a->{style} = undef
    #$a->{key}   = undef
    $a->{gradfn} = 'gradient' unless defined $a->{gradfn};
    $a->{weight} = 100	      unless defined $a->{weight};
    $a->{decay}  = 1	      unless defined $a->{decay};
    $a->{ramp}   = 0          unless defined $a->{ramp};
    $a->{smallest} = 0        unless defined $a->{smallest};
    $a->{sd}     = 2.00       unless defined $a->{sd};
    #$a->{cutoff}   = undef
    #$a->{gradient} = undef

    $a->{min} = 0             unless defined $a->{min};
    $a->{max} = $a->{weight}  unless defined $a->{max};
    $a->{max} = 100 if $a->{max} > 100;

    return $a;
}
 
sub shown_style {
    my $opt = shift;
    my $shown = 0;
    my $style;
    if (defined $opt) {
	if (ref $opt eq 'HASH' or ref $opt eq 'PostScript::Graph::Style') {
	    $style = $opt;
	    $shown = 1;
	} else {
	    $shown = $opt;
	}	
    }
    return ($shown, $style);
}

sub ensure_gradient {
    my ($s, $a) = @_;
    my ($gshown, $gstyle) = shown_style( $a->{gradient} );
    #warn "Momentum gradfn=$a->{gradfn}, shown=$gshown, style=", $gstyle ? $gstyle : '<undef>', "\n";
    
    my $id = line_id($a->{gradfn}, $a->{period}, $a->{line});
    my $base = $s->choose_line('cycles', $id, 1);
    unless ($base) {
	my $grad = call_function( \%function, $a->{gradfn}, $s,
	    graph  => $a->{graph},
	    line   => $a->{line},
	    period => $a->{period},
	    scaled => 0,
	    shown  => $gshown,
	    style  => $gstyle,
	    strict => $a->{strict},
	);
	$base = $s->{lines}{cycles}{$grad};
    }
    
    return $base->{data};
}

sub condition {
    my ($a, $level) = @_;
    my $lvl = $level - $a->{min};
    $lvl = $lvl*$a->{decay} + $a->{ramp};
    return $lvl + $a->{min};
}

sub create_lines {
    my ($s, $a, $res, $fn, $line_key, $level_key, $level) = @_;
    my ($cshown, $cstyle) = shown_style( $a->{cutoff} );

    my $id = line_id($fn, $a->{line});
    $s->add_line('tests', $id, $res, $line_key, $a->{style}, $a->{shown});
    
    $s->value(
	graph => 'cycles', 
	value => $level,
	key   => $level_key,
	shown => $cshown,
	style => $cstyle,
    ) if $cshown;

    return $id;
}

=head1 BUGS

The complexity of this software has seriously outstripped the testing, so there will be unfortunate interactions.
Please do let me know when you suspect something isn't right.  A short script working from a CSV file
demonstrating the problem would be very helpful.

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
