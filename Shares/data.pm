package Finance::Shares::data;
our $VERSION = 0.01;
use strict;
use warnings;
use Log::Agent;
use Text::CSV_XS;
use Finance::Shares::Support qw(
    out show add_show_objects
    $highest_int $lowest_int $number_regex
    ymd_from_string string_from_ymd days_difference today_as_string
    increment_ymd increment_date decrement_date day_of_week is_date
    check_dates check_file
);
use Finance::Shares::MySQL;
use Finance::Shares::Function;
our @ISA = 'Finance::Shares::Function';

=head1 NAME

Finance::Shares::data - Store quote prices and volumes for a particular stock

=head1 SYNOPSIS

    $data->write_csv($filename, $directory);

    $source = $data->source();
    $hash   = $data->dates_by();
    $date   = $data->start();
    $date   = $data->end();
    $date   = $data->first();
    $date   = $data->last();
    $array  = $data->dates();
    $hash   = $data->dates_hash();
    $date   = $data->idx_to_date($i);
    $i      = $data->date_to_idx($date);
    $i2     = $data->x_coord($i);
    $number = $data->nprices();
    $number = $data->nvolumes();

Inherited from L<Finance::Shares::Function>.  See that module for details.

    $name   = $data->id();
    $name   = $data->name();
    $fsc    = $data->chart();
    @names  = $data->line_ids();
    $fsl    = $data->line($name);
    @fsls   = $data->lines($regexp);
    $string = $data->show_lines();
    
=head1 DESCRIPTION

This module is used by L<Finance::Shares::Model> and L<fsmodel> and is not
intended for stand-alone use.  However, those features that may be useful to
module writers are documented here.

=head2 Data Structure

A Finance::Shares::data object is a L<Finance::Shares::Function> like all other
lower-case-named Finance::Share modules.  It holds five lines named:

    data/open
    data/high
    data/low
    data/close
    data/volume

L<Finance::Shares::Model> provides aliases for these using the B<names>
resource, so the 'data' suffix may usually be omitted.

    $closing_prices = $data->line('close');

The data lines are L<Finance::Shares::Line> objects, holding the raw data in
array format indexed to match the dates held here.  So this would print the
price range for each date:

    my $dates  = $data->dates();
    my $high   = $data->line('high');
    my $low    = $data->line('low');
    my $hidata = $high->data();
    my $lodata = $low->data();

    for (my $i = 0; $i <= $#$dates; $i++) {
	my $date    = $dates->[$i];
	my $highest = $hidata->[$i];
	my $lowest  = $lodata->[$i];
	print "$date : from $lowest to $highest\n";
    }

As well as array access, individual dates can also be checked directly using
a hash.  For example, to obtain the closing price for a given date:

    my $i = $data->date_to_idx('2003-06-14');
    my $close = $data->line('close');
    my $array = $close->data();
    my $closing_price = $array->[$i];
   
=head1 METHODS

=cut	
    
sub new {
    my $class = shift;
    my $o = new Finance::Shares::Function(@_);
    bless $o, $class;
   
    # additional fields
    # lx	=> {},	maps YYYY-MM-DD to x coord
    # dates	=> [],	sorted list of known dates
    # by		quotes/weekdays/days/weeks/months
    # start		first date to display
    # end		last date to display
    # first		first known date
    # last		last known date
    # before		periods hidden before start
    # after		periods shown after end
    # offset		{lx} value for {start}
    # nquotes		Number of dates
    # stock             stock symbol
    # fsc		FS::Chart
    # source            source of quotes

    out($o, 4, "new $class");
    return $o;
}

sub initialize {
    my $o = shift;
    $o->{function} = 'data';
    $o->{id} = 'data';

    $o->add_line('open',   shown => 0, gtype => 'price',  key => 'Opening price' );
    $o->add_line('high',   shown => 0, gtype => 'price',  key => 'Highest price' );
    $o->add_line('low',    shown => 0, gtype => 'price',  key => 'Lowest price'  );
    $o->add_line('close',  shown => 0, gtype => 'price',  key => 'Closing price' );
    $o->add_line('volume', shown => 0, gtype => 'volume', key => 'Trading volume');
    
    $o->{before} = 0 unless defined $o->{before};
    $o->{after} = 0 unless defined $o->{after};
    $o->set_default_dates;
}

sub set_default_dates {
    my $o = shift;
    check_dates($o);
    $o->{first} = decrement_date( $o->{start}, $o->{before}, $o->{by} ) if is_date $o->{start};
    $o->{last}  = decrement_date( $o->{end}, $o->{after}, $o->{by} )    if is_date $o->{end};
    logerr("Display start date before first fetched") unless $o->{first} le $o->{start};
    logerr("Last fetched after display end date")     unless $o->{last}  le $o->{end};
}

sub build {
    my $o = shift;
    return if $o->{built};
    out($o, 6, "build_data ". $o->name);
    my $src  = $o->{source};
    my $null = $o->model->null_value;
    if (ref($src) eq 'Finance::Shares::MySQL') {
	if ($o->{stock} and $o->{stock} ne $null) {
	    my @rows = $o->{source}->fetch(
		    symbol     => $o->{stock},
		    start_date => $o->{first},
		    end_date   => $o->{last},
		    mode       => $o->{mode},
		    verbose    => $o->{verbose},
		);
	    $o->prepare_dates(\@rows) if (@rows);
	} else {
	    $o->prepare_dates([
		    [$o->{start}],
		    [$o->{end}],
		]);
	}
    } elsif (ref($src) eq 'ARRAY') {
	$o->prepare_dates( $src );
    } elsif ($src and $src ne $null) {
	my @data;
	my $csv = new Text::CSV_XS;
	open(INFILE, "<", $src) or die "Unable to open \'$src\': $!\nStopped";
	while (<INFILE>) {
	    chomp;
	    my $ok = $csv->parse($_);
	    if ($ok) {
		my @row = $csv->fields();
		push @data, [ @row ] if (@row);
	    }
	}
	close INFILE;
	$o->prepare_dates( \@data );
    } else {
	# no source - return just start and end dates
	$o->prepare_dates([
		[$o->{start}, undef],
		[$o->{end},   undef],
	    ]);
    }
    $o->{fsc}->set_period($o->{start}, $o->{end});
    $o->finalize;
    out($o, 5, "$o->{by} from $o->{first} -($o->{before})- $o->{start} to $o->{last} -($o->{after})- $o->{end}");
}

sub write_csv {
    my ($o, $file, $dir) = @_;

    $file = "$o->{stock}-$o->{first}-$o->{last}.csv" if $file eq '1';
    my $filename = check_file($file, $dir);
    my $fs;
    if ($filename) {
	open ($fs, '>', $filename) or die "Unable to write to '$filename' : $!\n";
	select $fs;
    }

    my $dates = $o->{date_array};
    my $old = $o->line('open')->{data};
    my $hld = $o->line('high')->{data};
    my $lld = $o->line('low')->{data};
    my $cld = $o->line('close')->{data};
    my $vld = $o->line('volume')->{data};
    for (my $i = 0; $i <= $#$dates; $i++) {
	my $date   = $o->{date_array}[$i];
	my $open   = $old->[$i];
	my $high   = $hld->[$i];
	my $low    = $lld->[$i];
	my $close  = $cld->[$i];
	my $volume = $vld->[$i];
	printf('%s,%6.2f,%6.2f,%6.2f,%6.2f,%d%s',
	$date, $open, $high, $low, $close, $volume, "\n");
    }
    if ($filename) {
	close $fs;
	select STDOUT;
    }
    return $filename;
}

=head2 write_csv( filename [, directory ] )

Output all the data to the named file in CSV format.  No headings are output and
each line has these fields, comma seperated with no spaces:

    date, open, high, low, close, volume

This data file is in the correct format for using as a B<source> file in a Model
specification.

=cut
    
sub nearest {
    my ($o, $given, $ge, $data) = @_;
    $ge = 0 unless defined $ge;
    my ($before, $equal, $after) = ('', '', '');
    my $dates = $o->dates;
    foreach my $date (@$dates) {
	next if $data and not defined($data->{date});
	$before = $date, last if $given lt $date;
	$equal  = $date, last if $given eq $date;
	$after  = $date       if $given gt $date;
    }
    my $chosen;
    if ($ge) {
	$chosen = $equal || $after || $before;
    } else {
	$chosen = $equal || $before || $after;
    }
    #warn "given=$given, ge=$ge: $chosen (before=$before, equal=$equal, after=$after\n";
    return $chosen;
}

=head2 nearest( date [, after, [data]] )

Returns the date closest to C<date>.

C<after> indicates whether the next later or earlier date is prefered if an exact match is not found.  (Default:
0, earlier)

If given, C<data> should be a hash ref indexed by dates.  Only dates
belonging to this set are considered.

This works by scanning through all the dates, so it should be called once and the result stored if it is to be
needed again.

=cut

### ACCESS METHODS

sub source {
    return $_[0]->{source};
}

=head2 source( )

Return the source of the data as passed from L<Finance::Shares::Model>.  This
can be an array ref, a CSV file name or a L<Finance::Shares::MySQL> object -
giving database access.

=cut

sub dates_by {
    return $_[0]->{by};
}

=head2 dates_by( )

Return how the dates are counted.  One of quotes, weekdays, days, weeks, months.

=cut

sub start {
    return $_[0]->{start};
}

=head2 start( )

The first date from the user's point of view.  This is the date requested (or
close to it) and will normally be the first date displayed on the chart.

=cut

sub end {
    return $_[0]->{end};
}

=head2 end( )

The last date from the user's point of view.  This is the date requested (or
close to it) and will normally be the final date displayed on the chart.

=cut

sub first {
    return $_[0]->{first};
}

=head2 first( )

The first date stored in the line data.  This is derived from B<start> but
includes the maximum lead time required by functions working on the data.

=cut

sub last {
    return $_[0]->{last};
}

=head2 last( )

The date of the last data item stored.  B<end> may be after this if the user has
requested an extrapolation area.

=cut

sub dates {
    return $_[0]->{date_array} || [];
}

=head2 dates( )

An array ref holding all known dates.

    $d = $data->dates();
    
    $d->[0]    == $data->first();
    $d->[$#$d] == $data->last();

=cut

sub date_hash {
    return $_[0]->{date_hash};
}

=head2 date_hash( )

The index linking each date with its array offset.

    $d = $data->dates();
    $h = $data->date_hash();

    $date = $d->[$i];
    $h->{$date} == $i;

=cut

sub x_coord {
    my ($o, $i) = @_;
    return $i - $o->{offset};
}

=head2 x_coord( idx )

This converts the data array index into the equivalent display index, taking any
hidden leading data into account.

For example, if 21 quotes were needed to establish valid calculations, the first
date displayed (display index 0) would be data array element 20.

=cut

sub date_to_idx {
    my ($o, $date) = @_;
    return $o->{date_hash}{$date};
}

=head2 date_to_idx( date )

Return the data array index for a given date or undef if the date is not known.

=cut

sub idx_to_date {
    my ($o, $idx) = @_;
    return $o->{date_array}[$idx];
}

=head2 idx_to_date( index )

Return the date corresponding to the date array index given.

=cut

sub nprices {
    return $_[0]->{nprices};
}

=head2 nprices( )

Return the number of prices stored in the lines 'open', 'high', 'low' and
'close'.

=cut

sub nvolumes {
    return $_[0]->{nvolumes};
}

=head2 nvolumes( )

Return the number of volumes stored in the line 'volume'.  This is normally the
same as B<nprices>, but may be zero if no volume data was available.

=cut

sub chart {
    return $_[0]->{fsc};
}

=head2 chart( )

Return the L<Finance::Shares::Chart> displaying this data set.

=cut


sub model {
    my $fsc = $_[0]->{fsc};
    return $fsc->model;
}

=head2 model( )

Return the controlling L<Finance::Shares::Model>.

=cut


### SUPPORT METHODS

sub prepare_dates {
    my $o    = shift;
    my $data = shift;
    my $dtype = $o->{by};
   
    ## remove any headings from data
    unless (not $data->[0][1] or $data->[0][1] =~ $number_regex) {
	my $row = shift(@$data);
    }
    @$data = sort { $a->[0] cmp $b->[0] } @$data;
    $o->{first} = $data->[0][0];
    $o->{last}  = $data->[$#$data][0];
    $o->{start} = increment_date( $o->{first}, $o->{before}, $o->{by} );
    $o->{end}   = increment_date( $o->{last}, $o->{after}, $o->{by} );

    ## extract data
    my (%open, %high, %low, %close, %volume);
    my $count = 0;
    foreach my $row (@$data) {
	my ($date, $o, $h, $l, $c, $v) = @$row;
	$open{$date} = $o;
	$high{$date} = $h;
	$low{$date} = $l;
	$close{$date} = $c;
	$volume{$date} = $v if (defined $v);
	$count++;
    }
    $o->{nquotes} = $count;

    if ($dtype eq 'quotes') {
	$o->process_quotes(\%open, \%high, \%low, \%close, \%volume);
    } elsif ($dtype eq 'weekdays') {
	$o->process_weekdays(\%open, \%high, \%low, \%close, \%volume);
    } elsif ($dtype eq 'days') {
	$o->process_days(\%open, \%high, \%low, \%close, \%volume);
    } elsif ($dtype eq 'weeks') {
	$o->process_weeks(\%open, \%high, \%low, \%close, \%volume);
    } elsif ($dtype eq 'months') {
	$o->process_months(\%open, \%high, \%low, \%close, \%volume);
    }
}

sub process_quotes {
    my ($o, $open, $high, $low, $close, $volume) = @_;

    my ($endday, $enddate, $knowndate) = (0);
    my ($tdow, $tday, $tmonth, $tyear);
    my ($topen, $tclose, $thigh, $tlow, $tvolume, $total);
    my ($x, %lx, @dates) = 0;
    my @prev  = (0, 0, 0);
    my @first = ymd_from_string( $o->{first} );
    my @last  = ymd_from_string( $o->{end} );
    my $ndays = days_difference(@first, @last);
    my $pmin  = $highest_int;
    my $pmax  = $lowest_int;
    my $vmin  = $highest_int;
    my $vmax  = $lowest_int;
    for (my $i = 0; $i <= $ndays; $i++) {
	my @ymd     = increment_ymd(@first, $i, 'days');
	my $date    = string_from_ymd(@ymd);
	my ($year, $month, $day) = @ymd;
	my $dow     = day_of_week(@ymd);
	my $weekday = ($dow >= 1 and $dow <= 5);
	my $known   = $close->{$date};
	
	if ($known) {
	    #print "$date, x=$x, i=$i\n";
	    push @dates, $date;
	    $lx{$date} = $x++;
	    $pmin = $low->{$date}  if $low->{$date}  < $pmin;
	    $pmax = $high->{$date} if $high->{$date} > $pmax;
	    if (defined $volume->{$date}) {
		$vmin = $volume->{$date} if $volume->{$date} < $vmin;
		$vmax = $volume->{$date} if $volume->{$date} > $vmax;
	    }
	}
    }
    $o->define_data(\%lx, \@dates, $open, $high, $low, $close, $volume, $pmin, $pmax, $vmin, $vmax);
}

sub process_weekdays {
    my ($o, $open, $high, $low, $close, $volume) = @_;

    my ($endday, $enddate, $knowndate) = (0);
    my ($tdow, $tday, $tmonth, $tyear);
    my ($topen, $tclose, $thigh, $tlow, $tvolume, $total);
    my ($x, %lx, @dates) = 0;
    my @prev  = (0, 0, 0);
    my @first = ymd_from_string( $o->{first} );
    my @last  = ymd_from_string( $o->{end} );
    my $ndays = days_difference(@first, @last);
    my $pmin  = $highest_int;
    my $pmax  = $lowest_int;
    my $vmin  = $highest_int;
    my $vmax  = $lowest_int;
    for (my $i = 0; $i <= $ndays; $i++) {
	my @ymd     = increment_ymd(@first, $i, 'days');
	my $date    = string_from_ymd(@ymd);
	my ($year, $month, $day) = @ymd;
	my $dow     = day_of_week(@ymd);
	my $weekday = ($dow >= 1 and $dow <= 5);
	my $known   = $close->{$date};
	
	if ($weekday) {
	    push @dates, $date;
	    $lx{$date} = $x++;
	    $pmin = $low->{$date}  if defined($low->{$date}) and $low->{$date} < $pmin;
	    $pmax = $high->{$date} if defined($high->{$date}) and $high->{$date} > $pmax;
	    if (defined $volume->{$date}) {
		$vmin = $volume->{$date} if $volume->{$date} < $vmin;
		$vmax = $volume->{$date} if $volume->{$date} > $vmax;
	    }
	}
    }
    $o->define_data(\%lx, \@dates, $open, $high, $low, $close, $volume, $pmin, $pmax, $vmin, $vmax);
}

sub process_days {
    my ($o, $open, $high, $low, $close, $volume) = @_;

    my ($endday, $enddate, $knowndate) = (0);
    my ($tdow, $tday, $tmonth, $tyear);
    my ($topen, $tclose, $thigh, $tlow, $tvolume, $total);
    my ($x, %lx, @dates) = 0;
    my @prev  = (0, 0, 0);
    my @first = ymd_from_string( $o->{first} );
    my @last  = ymd_from_string( $o->{end} );
    my $ndays = days_difference(@first, @last);
    my $pmin  = $highest_int;
    my $pmax  = $lowest_int;
    my $vmin  = $highest_int;
    my $vmax  = $lowest_int;
    for (my $i = 0; $i <= $ndays; $i++) {
	my @ymd     = increment_ymd(@first, $i, 'days');
	my $date    = string_from_ymd(@ymd);
	my ($year, $month, $day) = @ymd;
	my $dow     = day_of_week(@ymd);
	my $weekday = ($dow >= 1 and $dow <= 5);
	my $known   = $close->{$date};
	
	push @dates, $date;
	$lx{$date} = $i;
	$pmin = $low->{$date}  if defined($low->{$date}) and $low->{$date} < $pmin;
	$pmax = $high->{$date} if defined($high->{$date}) and $high->{$date} > $pmax;
	if ($volume->{$date}) {
	    $vmin = $volume->{$date} if $volume->{$date} < $vmin;
	    $vmax = $volume->{$date} if $volume->{$date} > $vmax;
	}
    }
    $o->define_data(\%lx, \@dates, $open, $high, $low, $close, $volume, $pmin, $pmax, $vmin, $vmax);
}

sub process_weeks {
    my ($o, $open, $high, $low, $close, $volume) = @_;

    my ($endday, $enddate, $knowndate) = (0);
    my ($tdow, $tday, $tmonth, $tyear);
    my ($topen, $tclose, $thigh, $tlow, $tvolume, $total);
    my ($x, %lx, @dates) = 0;
    my @prev  = (0, 0, 0);
    my @first = ymd_from_string( $o->{first} );
    my @last  = ymd_from_string( $o->{end} );
    my $ndays = days_difference(@first, @last);
    my $pmin  = $highest_int;
    my $pmax  = $lowest_int;
    my $vmin  = $highest_int;
    my $vmax  = $lowest_int;
    for (my $i = 0; $i <= $ndays; $i++) {
	my @ymd     = increment_ymd(@first, $i, 'days');
	my $date    = string_from_ymd(@ymd);
	my ($year, $month, $day) = @ymd;
	my $dow     = day_of_week(@ymd);
	my $weekday = ($dow >= 1 and $dow <= 5);
	my $known   = $close->{$date};
	
	# Each weeks data accumulates until the next week begins.
	# So at the start of each week, the previous week's data are
	# recorded under the last recorded weekday (usually Friday).
	if ($weekday) {
	    # $dow: 1=Monday .. 7=Sunday
	    if ($dow >= $endday) { 
		if ($known) {
		    # add values to totals for week
		    $total++;
		    $topen   += $open->{$date};
		    $thigh   += $high->{$date};
		    $tlow    += $low->{$date};
		    $tclose  += $close->{$date};
		    $tvolume += $volume->{$date} if defined $volume->{$date};
		    # remove days data
		    delete $open->{$date};
		    delete $high->{$date};
		    delete $low->{$date};
		    delete $close->{$date};
		    delete $volume->{$date};
		    # note this as last date known so far
		    $knowndate = $date;
		} elsif ($dow == 5) {
		    $knowndate = $date;
		}
		$tdow=$dow; $tday=$day; $tmonth=$month; $tyear=$year;
	    } else {
		# Monday
		if (defined $knowndate) { 
		    # put last weeks totals into last known date
		    if ($total) {
			$open->{$knowndate}   = $topen/$total;
			$high->{$knowndate}   = $thigh/$total;
			$low->{$knowndate}    = $tlow/$total;
			$close->{$knowndate}  = $tclose/$total;
			$volume->{$knowndate} = $tvolume/$total if $tvolume;
			$pmin = $low->{$knowndate}  if $low->{$knowndate}  < $pmin;
			$pmax = $high->{$knowndate} if $high->{$knowndate} > $pmax;
			if (defined $volume->{$knowndate}) {
			    $vmin = $volume->{$knowndate} if $volume->{$knowndate} < $vmin;
			    $vmax = $volume->{$knowndate} if $volume->{$knowndate} > $vmax;
			}
		    }
		    push @dates, $knowndate;
		    $lx{$knowndate} = $x++;
		}
		# clear for a new week
		if ($known) {
		    $total   = 1;
		    $topen   = $open->{$date};
		    $thigh   = $high->{$date};
		    $tlow    = $low->{$date};
		    $tclose  = $close->{$date};
		    $tvolume = $volume->{$date} if defined $volume->{$date};
		    # remove days data
		    delete $open->{$date};
		    delete $high->{$date};
		    delete $low->{$date};
		    delete $close->{$date};
		    delete $volume->{$date};
		} else {
		    $topen = $thigh = $tlow = $tclose = $tvolume = $total = 0;
		}
		$knowndate  = undef;
	    }
	    $endday = $dow;
	}
    }
    $o->define_data(\%lx, \@dates, $open, $high, $low, $close, $volume, $pmin, $pmax, $vmin, $vmax);
}

sub process_months {
    my ($o, $open, $high, $low, $close, $volume) = @_;

    my ($endday, $enddate, $knowndate) = (0);
    my ($tdow, $tday, $tmonth, $tyear);
    my ($topen, $tclose, $thigh, $tlow, $tvolume, $total);
    my ($x, %lx, @dates) = 0;
    my @prev  = (0, 0, 0);
    my @first = ymd_from_string( $o->{first} );
    my @last  = ymd_from_string( $o->{end} );
    my $ndays = days_difference(@first, @last);
    my $pmin  = $highest_int;
    my $pmax  = $lowest_int;
    my $vmin  = $highest_int;
    my $vmax  = $lowest_int;
    for (my $i = 0; $i <= $ndays; $i++) {
	my @ymd     = increment_ymd(@first, $i, 'days');
	my $date    = string_from_ymd(@ymd);
	my ($year, $month, $day) = @ymd;
	my $dow     = day_of_week(@ymd);
	my $weekday = ($dow >= 1 and $dow <= 5);
	my $known   = $close->{$date};
	
	# Each months data accumulates until the next month begins.
	if ($weekday) {
	    if ($day >= $endday) {
		if ($known) {
		    $total++;
		    $topen   += $open->{$date};
		    $thigh   += $high->{$date};
		    $tlow    += $low->{$date};
		    $tclose  += $close->{$date};
		    $tvolume += $volume->{$date} if defined $volume->{$date};
		    delete $open->{$date};
		    delete $high->{$date};
		    delete $low->{$date};
		    delete $close->{$date};
		    delete $volume->{$date};
		    $knowndate = $date;
		}
		$tdow=$dow; $tday=$day; $tmonth=$month; $tyear=$year;
	    } else {
		# 1st working day of new month
		if (defined $knowndate) { 
		    if ($total) {
			$open->{$knowndate}   = $topen/$total;
			$high->{$knowndate}   = $thigh/$total;
			$low->{$knowndate}    = $tlow/$total;
			$close->{$knowndate}  = $tclose/$total;
			$volume->{$knowndate} = $tvolume/$total;
			$pmin = $low->{$knowndate}  if $low->{$knowndate}  < $pmin;
			$pmax = $high->{$knowndate} if $high->{$knowndate} > $pmax;
			if (defined $volume->{$knowndate}) {
			    $vmin = $volume->{$knowndate} if $volume->{$knowndate} < $vmin;
			    $vmax = $volume->{$knowndate} if $volume->{$knowndate} > $vmax;
			}
		    }
		} else {
		    $knowndate = $enddate;
		}
		push @dates, $knowndate;
		$lx{$knowndate} = $x++;
		
		# clear for a new month
		if ($known) {
		    $total   = 1;
		    $topen   = $open->{$date};
		    $thigh   = $high->{$date};
		    $tlow    = $low->{$date};
		    $tclose  = $close->{$date};
		    $tvolume = $volume->{$date} if defined $volume->{$date};
		    delete $open->{$date};
		    delete $high->{$date};
		    delete $low->{$date};
		    delete $close->{$date};
		    delete $volume->{$date};
		} else {
		    $topen = $thigh = $tlow = $tclose = $total = 0;
		}
		$knowndate  = undef;
	    }
	    $endday = $day;
	    $enddate = $date;
	}
    }
    $o->define_data(\%lx, \@dates, $open, $high, $low, $close, $volume, $pmin, $pmax, $vmin, $vmax);
}

sub define_data {
    my ($o, $lxH, $dates, $openH, $highH, $lowH, $closeH, $volumeH, $pmin, $pmax, $vmin, $vmax) = @_;

    $o->{date_hash}  = $lxH;	# YYYY-MM-DD => x coordinate on chart; keys give definitive list of dates
    $o->{date_array} = $dates;	# array where each index x => YYYY-MM-DD
    $o->{first}   = $dates->[0];
    $o->{last}    = $dates->[$#$dates];
    $o->{start}   = $dates->[0] if $o->{start} lt $dates->[0];
    $o->{end}     = $o->{last};
    
    # Calculate start for x coordinate
    foreach my $date (@$dates) {
	next if $date lt $o->{start};
	next unless defined $date;
	$o->{offset} = $lxH->{$date};
	last if defined $o->{offset};
    }
    
    # Patch to turn the hashes into arrays
    # At some point I might rewrite prepare_dates for arrays, but then again...
    my (@open, @high, @low, @close, @volume);
    my $nprices = 0;
    my $nvolumes = 0;
    for (my $i = 0; $i <= $#$dates; $i++) {
	my $date = $dates->[$i];
	$open[$i]   = $openH->{$date};
	$high[$i]   = $highH->{$date};
	$low[$i]    = $lowH->{$date};
	$close[$i]  = $closeH->{$date};
	$volume[$i] = $volumeH->{$date};
	$nprices++ if defined $close[$i];
	$nvolumes++ if defined $volume[$i];
    }
    $o->{nprices} = $nprices;
    $o->{nvolumes} = $nvolumes;
    
    my $line;
    $line = $o->line('open');
    $line->{data} = \@open;
    $line = $o->line('high');
    $line->{data} = \@high;
    $line = $o->line('low');
    $line->{data} = \@low;
    $line = $o->line('close');
    $line->{data} = \@close;
    $line = $o->line('volume');
    $line->{data} = \@volume;
}
    
=head1 BUGS

Please let me know when you suspect something isn't right.  A short script
working from a CSV file demonstrating the problem would be very helpful.

=head1 AUTHOR

Chris Willmot, chris@willmot.org.uk

=head1 LICENCE

Copyright (c) 2002-2003 Christopher P Willmot

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
A copy can be found at L<http://www.gnu.org/copyleft/gpl.html>

=head1 SEE ALSO

L<Finance::Shares::Overview> provides an introduction to the suite, and
L<fsmodel> is the principal script.

Modules involved in processing the model include L<Finance::Shares::Model>,
L<Finance::Shares::MySQL>, L<Finance::Shares::Chart>.
Chart and file details may be found in L<PostScript::File>,
L<PostScript::Graph::Paper>, L<PostScript::Graph::Key>,
L<PostScript::Graph::Style>.

All functions are invoked from their own modules, all with lower-case names such
as L<Finance::Shares::moving_average>.  The nitty-gritty on how to write each
line specification are found there.

The quote data is stored in a L<Finance::Shares::data> object.
For information on writing additional line functions see
L<Finance::Share::Function> and L<Finance::Share::Line>.
Also, L<Finance::Share::test> covers writing your own tests.

=cut

