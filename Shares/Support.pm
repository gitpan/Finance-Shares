package Finance::Shares::Support;
our $VERSION = 1.03;
use strict;
use warnings;
use Date::Calc qw(:all);
use Exporter;
use Data::Dumper;
use Log::Agent qw(logwrite logerr);
use PostScript::File qw(check_file);
use DBIx::Namespace;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    $highest_int $lowest_int %period $number_regex $default_line_style
    $field_split $field_join
    today_as_string is_date string_from_ymd ymd_from_string
    increment_ymd increment_date decrement_ymd decrement_date
    days_difference day_of_week
    read_config write_config deep_copy valid_gtype extract_list
    check_file check_filesize check_by check_dates
    mysql_present unique_name internal_name shown_style
    name_split name_join name_flatten
    show_dump show show_deep 
    add_show_objects show_addresses show_indent show_seperator
    out outf out_indent 
    line_dump line_compare array_from_file
);

# Used for constructing Key text
our %period = (
    quotes   => 'quote',
    weekdays => 'weekday',
    days     => 'day', 
    weeks    => 'week', 
    months   => 'month',
    undef    => 'period',
);

our $default_line_style = {
    bgnd_outline => 0,
    line => {
	inner_width => 1.5,
	outer_width => 2,
    },
};

our $monotonic    = 0;
our $highest_int  = 10 ** 20;	# how do you set these properly?
our $lowest_int   = -$highest_int;
our $number_regex = qr/^\s*[-+]?[0-9.]+(?:[Ee][-+]?[0-9.]+)?\s*$/;
our $field_split  = '\/';
our $field_join   = '/';

our @show_objects;		# list of ref() strings that show_deep should expand
our $show_addresses = 0;	# switch for show_deep
our $show_indent = '  ';	# lead string for show_deep 
our $show_indent_regexp = '  ';	# lead string for show_deep
our $show_seperator = ', ';     # comma for show_deep
our $indent_level = 0;		# nesting for out and outf

 sub show;

=head1 NAME

Finance::Shares::Support - Miscellaneous functions

=head1 SYNOPSIS

    use Finance::Shares::Support qw(
	    today_as_string
	    string_from_ymd
	    ymd_from_string
	    increment_days
	    increment_date
	    days_difference
	    day_of_week
	);

 
=head1 DESCRIPTION

=cut

sub read_config {
    my ($file) = @_;
    $file = '~/.fs/model.conf' unless $file;
    my $filename = check_file($file);
    return undef unless -e $filename;
    my @contents = do $filename;
    logerr("Error reading config file '$filename'\n\t$@") if $!;
    return wantarray ? @contents : $contents[0];
}

sub write_config {
    my ($file) = shift;
    $file = '~/.fs/model.conf' unless $file;
    my $filename = check_file($file, undef, 1);
    unless (open(FILE, '>', $filename)) {
	logerr "Cannot write to config file '$filename'";
	return;
    }
    foreach my $item (@_) {
	print FILE show_deep($item);
    }
    close FILE;
}    

sub deep_copy {
    my ($orig) = @_;
    return undef unless defined $orig;
    my $ref = ref $orig;
    my $copy;

    if ($ref eq 'HASH') {
	$copy = {};
	foreach my $key (keys %$orig) {
	    my $value = $orig->{$key};
	    $copy->{$key} = deep_copy($value);
	}
    } elsif ($ref eq 'ARRAY') {
	$copy = [];
	foreach my $value (@$orig) {
	    push @$copy, deep_copy($value);
	}
    } else {
	$copy = $orig;
    }

    return $copy;
}

=head2 deep_copy( var )

C<var> is returned unless it is, or contains, a hash ref or  an array ref.  These are copied recursively and the
copy is returned.

=cut

sub valid_gtype {
    my $given = shift;
    foreach my $gtype (qw(price volume analysis logic)) {
	return 1 if $given eq $gtype;
    }
    return 0;
}

sub name_split {
    my $name = shift;
    my ($s, $c, $p, $f, $l) = split /$field_split/, $name;
    if ($l) {
	return ( $s, $c, $p, $f, $l );
    } else {
	return ( $s, $c, $p, $f );
    }
}

=head2 name_split( name )

Returns the list of fields.  Of course if a partial name is given the name is split accordingly.  Typical results
are
    
    (sample, stock, period, fntag, line)
    (sample, stock, period, fntag)
    (fntag, line)
    (fntag)
    
=cut

sub name_join {
    no warnings;
    return join($field_join, @_);
}

=head2 name_join( list )

Returns a string containing a canonical name for a Finance::Shares object.

The list of strings must be in the correct order: 

    sample, stock, period, function, line.
    
The canonical name for the parent plus the child object ID is also acceptable.

=cut

sub name_flatten {
    my ($name, $char) = @_;
    my $res;
    ($res = $name) =~ s/$field_split/$char/g;
    return $res;
}

=head2 name_flatten( name, char )

Remove seperator characters ('/') from C<name>, replacing them with C<char>.

=cut


sub check_dates {
    my ($h, $defstart, $defend, $defby) = @_;
    check_by($h, $defby);
    $h->{end}   = $defend   || today_as_string() unless is_date($h->{end}); 
    $h->{start} = $defstart || decrement_date($h->{end}, 60, $h->{by}) unless is_date($h->{start});
}

sub check_by {
    my ($h, $defby) = @_;
    my $by = $h->{by} || $defby || '';
    my $ok = 0;
    foreach my $period (qw(quotes weekdays days weeks months)) {
	$ok = 1, last if $by eq $period;
    }
    $by = 'weekdays' unless $ok;
    $h->{by} = $by;
} 


sub extract_list {
    my $val = shift;
    return unless $val;
    if (ref($val) eq 'ARRAY') {
	my @res;
	foreach my $item (@$val) {
	    push @res, extract_list($item);
	}
	return @res;
    } else {
	return $val;
    }
}
## extract_list( val )
#
# val  Can be list-of-lists, list or scalar.
#
# Return a list of array-refs, each holding specs for one line.

sub mysql_present {
    my $db;
    eval {
	$db = new DBIx::Namespace ( @_ );
    };
    if ($@) {
	return 0;
    }

    $db->disconnect;
    return 1;
}
## mysql_present( @args )
#
# @args should include e.g.
#   user     => 'test',
#   password => 'test',
#   database => 'test'
#   
# Return 1 if a MySQL connect was made, 0 if not.

sub unique_name {
    my $stem = shift;
    $stem = 'unique_name' unless defined $stem;
    return "_$stem" . $monotonic++;
}
## unique_name( stem )

sub internal_name {
    my $name = '_' . join('_', @_);
    $name =~ s/$field_split/_/;
    return $name;
}
## internal name( args )
#
# returns e.g. '_arg1_arg2_arg3'

sub shown_style {
    my $val = shift;
    my $shown = 0;
    my $style = undef;

    if ($val) {
	$shown = 1;
	$style = ref($val) ? $val : $default_line_style;
    }

    return ($shown, $style);
}

=head2 shown_style( value )

Return a list C<($shown, $style)> depending on the value given.

=over

=item '0'

The line is hidden.  Returns (0, undef).

=item '1'

The line is visible with the default style.  Returns (1, undef).

=item hash ref

The line uses a style created from this specification.  Returns (1, hashref).

=item L<PostScript::Graph::Style> object

The line is shown with the style given.  Returns (1, object).

=back

=cut

=head1 DATE FUNCTIONS

There are three types of dates here.  A 'days' value is the number of days from some arbitrary day zero.  A 'date'
is a string in YYYY-MM-DD format while 'ymd' refers to an array holding a year, month and day such as (2002, 12,
31).  See L<SYNOPSIS> for all the functions.

=cut

sub today_as_string () {
    return sprintf("%04d-%02d-%02d", Today());

}

=head2 today_as_string

Return today's date in YYYY-MM-DD format.

=cut

sub is_date {
    my @ymd = ymd_from_string( shift );
    return (@ymd == 3);
}

sub string_from_ymd (@) {
    return sprintf("%04d-%02d-%02d", @_);
}

=head2 string_from_ymd( year, month, day )

Convert the numeric representation of year, month and day into a YYYY-MM-DD date.

=cut

sub ymd_from_string ($) {
    my $string = shift;
    return undef unless $string;
    return ($string =~ /(\d{4})-(\d{2})-(\d{2})/);
}

=head2 ymd_from_string( date )

Convert a YYYY-MM-DD date into an array of numeric values in the form:

    (year, month, day)

=cut

sub increment_ymd {
    my ($y, $m, $d, $inc, $period) = @_;
    $period = 'weekdays' if $period eq 'quotes';
    $period = 'days' if not $period;
    if ($period eq 'weekdays') {
	my $weeks = int($inc/5);
	my $days  = $inc % 5;
	return Add_Delta_Days($y, $m, $d, ($weeks*7)+$days);
    } elsif ($period eq 'days') {
	return Add_Delta_Days($y, $m, $d, $inc);
    } elsif ($period eq 'weeks') {
	return Add_Delta_Days($y, $m, $d, $inc*7);
    } elsif ($period eq 'months') {
	return Add_Delta_YM($y, $m, $d, 0, $inc);
    }
}

=head2 increment_ymd( year, month, day, inc, period )

Add C<inc> periods to the date and return as a year-month-day array.  C<period> can be one of quotes, weekdays,
days, weeks or months.

=cut

sub decrement_ymd {
    my ($y, $m, $d, $inc, $period) = @_;
    $period = 'weekdays' if $period eq 'quotes';
    $period = 'days' if not $period;
    if ($period eq 'weekdays') {
	my $weeks = int($inc/5);
	my $days  = $inc % 5;
	return Add_Delta_Days($y, $m, $d, -($weeks*7)-$days);
    } elsif ($period eq 'days') {
	return Add_Delta_Days($y, $m, $d, -$inc);
    } elsif ($period eq 'weeks') {
	return Add_Delta_Days($y, $m, $d, -$inc*7);
    } elsif ($period eq 'months') {
	return Add_Delta_YM($y, $m, $d, 0, -$inc);
    }
}

=head2 decrement_ymd( year, month, day, dec, period )

Subtract C<dec> periods to the date and return as a year-month-day array.
C<period> can be one of quotes, weekdays, days, weeks or months.

=cut

sub increment_date {
    my ($string, $inc, $period) = @_;
    $period = 'weekdays' if $period eq 'quotes';
    $period = 'days' if not $period;
    my @date = ymd_from_string( $string );
    my @newdate = increment_ymd( @date, $inc, $period );
    return string_from_ymd( @newdate );
}

=head2 increment_date( date, inc, period )

Add C<inc> periods to the YYYY-MM-DD date and return the new date in YYYY-MM-DD format.
C<period> can be one of quotes, weekdays, days, weeks or months.

=cut


sub decrement_date {
    my ($string, $dec, $period) = @_;
    $period = 'weekdays' if $period eq 'quotes';
    $period = 'days' if not $period;
    my @date = ymd_from_string( $string );
    my @newdate = decrement_ymd( @date, $dec, $period );
    return string_from_ymd( @newdate );
}

=head2 decrement_date( date, dec, period )

Subtract C<dec> periods to the YYYY-MM-DD date and return the new date in YYYY-MM-DD format.
C<period> can be one of quotes, weekdays, days, weeks or months.

=cut


sub days_difference {
    my ($y1, $m1, $d1, $y2, $m2, $d2) = @_;
    return Delta_Days($y1, $m1, $d1, $y2, $m2, $d2);
}

=head2 days_difference( year1, month1, day1, year2, month2, day2 )

Return the number of days between the two dates

=cut

sub day_of_week {
    return Day_of_Week(@_);
}

=head2 day_of_week( year, month, day )

Returns 1=Monday, ... 7=Sunday.

=cut

=head1 DEBUGGING

=cut

sub out {
    my ($o, $lvl, @args) = @_;
    logwrite('debug', $lvl, ' ' . ('  ' x $indent_level) . join('', @args)) if $lvl <= $o->{verbose};
}

=head2 out(obj, lvl, msg)

Send a message to STDERR if the verbosity setting is greater than or equal to C<lvl>.  C<msg> can be a list or
a single string, like C<print>.

C<obj> must have {verbose} field.

=cut

sub out_indent {
    my $inc = shift;
    $indent_level += $inc;
}

=head2 out_indent( inc )

Make a relative change to the depth of indentation used by C<out> and C<outf>.

=cut

sub add_show_objects {
    push @show_objects, @_;
}

sub show_addresses {
    my $arg = shift;
    $arg = 1 unless defined $arg;
    $show_addresses = $arg;
}


=head2 show_addresses ( [arg] )

Determines whether B<show> displays structure addresses.  These are useful in complex structires as each hash or
array ref is shown only once.  C<arg> should be 1 or 0.  (Default: 1)

=cut

#sub show_seperator {
#    my $arg = shift;
#    $arg = ', ' unless defined $arg;
#    $show_seperator = $arg;
#}
#
#=head2 show_seperator( [string] )
#
#Seperator between simple values.  (Default: ', ')
#
#=cut

sub show_indent {
    my ($arg, $regexp) = @_;
    $arg = ':   ' unless defined $arg;
    $regexp = $arg unless defined $regexp;
    $show_indent = $arg;
    $show_indent_regexp = $regexp;
}

=head2 show_indent( [string [, regexp]] )

This declares the string B<show> uses for one indent.  The optional regular expression is required if C<string>
uses characters such as '|' which have special meanings.  If the indent string can't be matched, closing brackets
aren't aligned correctly.  (Default: ':   ')

=cut

sub hash_equiv {
    my $ref = shift;
    foreach my $name ('HASH', @show_objects) {
	return 1 if $ref eq $name;
    }
    return 0;
}


sub in_list {
    my ($var, $path) = @_;
    foreach my $item (@$path) {
	return 1 if $item == $var;
    }
    return 0;
}

sub show {
    my ($msg, $var, $level) = @_;
    my $res = show_deep($var, $level);
    $res .= "\n" unless $res =~ /\n$/m;
    $var = '<undef>' unless defined $var;
    my $addr = $show_addresses ? "(==$var==)" : '';
    warn "$msg $addr...\n", $res;
}

=head2 show( msg, var )

Uses B<warn> to output the message followed by C<show_deep($var, $level)>.

=cut

sub show_deep {
    my ($var, $min, $sep) = @_;
    return "<undef>\n" unless defined $var;
    $sep = $show_seperator unless defined $sep;
    $sep = ' ' unless defined $sep;
    my $ref = ref($var);
    if (hash_equiv $ref) {
	return show_hash([], $var, $min, $sep);
    } elsif ($ref eq 'ARRAY') {
	return show_array([], $var, $min, $sep);
    } else {
	return $var;
    }
}
	
=head2 show_deep( var [, min [, sep]] )

B<NOTE> this is an exported function, not a method.

Recursively dumps hash or array refs, returning a string which may be displayed with
e.g. B<warn>.  Normally only plain hashes or arrays are expanded.  However, by setting the exported variable
C<@show_objects> to a list of classes, all such objects are expanded, too.

=over 8

=item var

The scalar variable to be printed.

=item min

A limit to the depth printed out.

=item sep

String used to seperate entries (between pairs, not within them).

=back

Example

    warn "MyModule:666\n", show_deep($h, 2);

might produce something like the following, with 2 levels (chart1, and background etc.).  Deeper arrays and hashes
are not expanded.
    
    {chart1=>
      {background=>ARRAY(0x87573cc),
      dots_per_inch=>75, invert=>1, 
      key=>HASH(0x87547a4)}
    
=cut

sub show_hash {
    my ($path, $h, $min, $sep, $depth) = @_;
    $min = -1   unless defined $min;
    $sep = ', ' unless defined $sep;
    $depth = 0  unless defined $depth;
    my $tab = $depth ? ($show_indent x $depth) : '';
    return $h unless ($min);
    return "<see " . $h . ">\n" if in_list($h, $path);
    push @$path, $h;
    my $res = '';
    if ($h and hash_equiv(ref($h))) {
	$res .= "\n" . $tab if $depth;
	$res .= "{ ";
	my $entry = 0;
	foreach my $k (sort keys %$h) {
	    my $v = $h->{$k};
	    my $key   = defined($k) ? $k : '<undef>';
	    my $value = defined($v) ? $v : '<undef>';
	    $res .= $sep if $entry;
	    $res .= $tab if $sep =~ /\n$/;
	    $res .= "$key=>";
	    if (hash_equiv(ref $value)) {
		$res .= "\n$tab  =$value=  " if $show_addresses and not in_list($value, $path) and ($min-1);
		$res .= show_hash($path, $value, $min-1, $sep, $depth+1);
		$res .= $tab if ($min-1);
	    } elsif (ref($value) eq 'ARRAY') {
		$res .= "\n$tab  =$value=  " if $show_addresses and not in_list($value, $path) and ($min-1);
		$res .= show_array($path, $value, $min-1, $sep, $depth+1);
		$res .= $tab if ($min-1);
	    } else {
		$res .= $value;
	    }
	    $entry = 1;
	}
	$res .= ($res =~ /\n(?:$show_indent_regexp)*$/) ? "}\n" : " }\n";
    } else {
	$res = "$h\n";
    }
    pop @$path;
    return $res;
}

sub show_array {
    my ($path, $ar, $min, $sep, $depth) = @_;
    $min = -1   unless defined $min;
    $sep = ', ' unless defined $sep;
    $depth = 0 unless defined $depth;
    my $tab = $depth ? ($show_indent x $depth) : '';
    return "<see " . $ar . ">\n" if in_list($ar, $path);
    return $ar unless ($min);
    push @$path, $ar;
    my $res = '';
    if ($ar and ref($ar) eq 'ARRAY') {
	$res .= "\n" . $tab if $depth;
	$res .= "[ ";
	my $entry = 0;
	foreach my $v (@$ar) {
	    my $value = defined($v) ? $v : '<undef>';
	    $res .= $sep if $entry;
	    if (hash_equiv(ref $value)) {
		$res .= "\n$tab  =$value=  " if $show_addresses and not in_list($value, $path) and ($min-1);
		$res .= show_hash($path, $value, $min-1, $sep, $depth+1);
		$res .= $tab if ($min-1);
	    } elsif (ref($value) eq 'ARRAY') {
		$res .= "\n$tab  =$value=  " if $show_addresses and not in_list($value, $path) and ($min-1);
		$res .= show_array($path, $value, $min-1, $sep, $depth+1);
		$res .= $tab if ($min-1);
	    } else {
		$res .= $value;
	    }
	    $entry = 1;
	}
	$res .= ($res =~ /\n(?:$show_indent_regexp)*$/) ? "]\n" : " ]\n";
    }
    return $res;
}



sub show_dump {
    $Data::Dumper::Indent = 1;
    return Data::Dumper->Dump(@_);
}

=head2 show_dump( [values...], [names...] )

Calls Data::Dumper on values passed.
Returns a string which may be displayed with e.g. B<warn>.

=cut


sub check_filesize {
    my ($psfile, $filesizes, $write) = @_;
    $write = 0 unless defined $write;
    my $create = 0;
    my $pssize = -s $psfile;
    my %fs;
    
    if (open(IN, '<', $filesizes)) {
	while (<IN>) {
	    chomp;
	    my ($size, $file) = m/^(\d+)\t(.+)$/;
	    $fs{$file} = $size;
	}
	close IN;
    } else {
	warn "Cannot read size file '$filesizes': $!\n";
	$create = 1;
    }
    
    my $exists = $fs{$psfile};
    my $res = $exists ? ($fs{$psfile} == $pssize) : 1;
    warn "Cannot check size of '$psfile' : No size stored\n" unless $exists;
    $fs{$psfile} = $pssize if $write;
    
    if ($write or $create) {
	open(OUT, '>', $filesizes) or die "Unable to write to $filesizes : $!\n";
	while( my ($file, $size) = each %fs ) {
	    print OUT "$size\t$file\n" if defined $file and defined $size;
	}
	close OUT;
    }

    return $res;
}

=head2 check_filesize( filename, filesizes [, $write] )

Returns 1 if the named file is the size recorded in the file F<filesizes>, 0 if the size is different.

If F<files> doesn't exist or the name is not found, 1 is returned but warnings are given.  C<write> is assumed
unless it is set to 0.

=cut


sub line_dump {
    my ($array, $filename) = @_;
    open(OUT, '>', $filename) or die "Unable to write to '$filename'";
    print OUT show_dump([$array], ['data']);
    close OUT;
}

sub line_compare {
    my ($array, $filename, $error) = @_;
    $error = 0.5 unless defined $error;
    die "No line data\n" unless ref $array eq 'ARRAY';
    die "No file called '$filename'\n" unless -e $filename;
    my $data = do $filename;
    die "'$filename' doesn't hold a data array\n" unless ref $data eq 'ARRAY';
    my $asz = @$array;
    my $dsz = @$data;
    warn "Different sizes: line=$asz, file=$dsz\n", return 0 unless $asz == $dsz;
    my $count = 0;
    for (my $i = 0; $i <= $#$data; $i++) {
	my $av = $array->[$i];
	my $dv = $data->[$i];
	if (defined $av and defined $dv) {
	    unless (abs($av - $dv) <= $error) {
		$count++;
		warn "at $i\: line=$av, file=$dv\n";
	    }
	} else {
	    unless (not defined $av and not defined $dv) {
		$count++;
		warn "at $i\: line=", $av || '<undef>', ", file=", $dv || '<undef>', "\n";
	    }
	}
    }
    if ($count) {
	warn "$count error", ($count == 1 ? '' : 's'), "\n";
	return 0;
    } else {
	return 1;
    }
}

sub array_from_file {
    my $file = shift;
    open(IN, '<', $file) or die "Unable to open '$file' : $!\n";
    my @array;
    while( <IN> ) {
	chomp;
	s/^\s+//;
	s/\s+$//;
	push @array, $_;
    }
    return \@array;
}

=head1 AUTHOR

Chris Willmot, chris@willmot.org.uk

=head1 SEE ALSO

L<Finance::Shares::MySQL>,
L<Finance::Shares::Chart> and
L<Finance::Shares::Model>.

There is also an introduction, L<Finance::Shares::Overview> and a tutorial beginning with
L<Finance::Shares::Lesson1>.

=cut

1;

