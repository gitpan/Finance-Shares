package TestFuncs;
our $VERSION = '0.03';
use strict;
#use warnings;
use Test::Builder;
use Data::Dumper;
use Exporter;
use Text::CSV_XS;
use Carp;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(is_same deep_copy
		    from_csv array_to_sample csv_to_sample sample_to_csv
		    show show_deep show_hash show_array show_lines show_graph_lines
		    check_filesize
		);

our $Test = new Test::Builder;

=head1 NAME

TestFuncs - routines used by several tests

=head1 SYNOPSIS

    use Test::Structs qw(is_same is_numeric);

    is_same($ref1, $ref2, 'test name');
    is_same($ref1, $ref2, 'test name', 0.1);
    is_numeric($scalar);

=head1 DESCRIPTION

Used in the same was as Test::Simple and Test::More, this adds my home rolled tests.

=cut

sub is_same {
    my ($a1, $a2, $test_name, $accuracy) = @_;
    $accuracy = 0 unless defined $accuracy;
    my $result = _structs($a1, $a2, $accuracy, '');
    if (defined $result) {
	my ($v1, $v2, $posn)  = @$result;
	$v1 = '<undef>' unless defined $v1;
	$v2 = '<undef>' unless defined $v2;
	$Test->diag("    Difference more than $accuracy at: $posn");
	$Test->diag("             got: $v1");
	$Test->diag("        expected: $v2");
	$Test->ok(0,$test_name);
    } else {
	$Test->ok(1,$test_name);
    }
}

=head2 is_same( ref1, ref2 [, test_name [, accuracy]] )

C<ref1> and C<ref2> can be references to arrays or hashes.  The structures are compared item by item, including
any sub-arrays or sub-hashes.  If C<accuracy> is specified, numbers may differ by this amount before the test
fails.

TODO: 
    Doesn't handle blessed references
    Reporting of deep errors not really tested

=cut

# returns [ value1, value2, position ] if failed, undef if OK.
sub _structs {
    my ($r1, $r2, $accuracy, $posn) = @_;
    if (defined $r1 and defined $r2) {
	my $ref1 = ref $r1;
	my $ref2 = ref $r2;
	return [$r1, $r2, $posn] unless $ref1 eq $ref2;
	if ($ref1 eq '') {
	    if (_numeric($r1) and _numeric($r2)) {
		my $diff = abs($r1 - $r2);
		if ($diff <= $accuracy) {
		    return undef;
		} else {
		    return [$r1, $r2, $posn];
		}
	    } else {
		if ($r1 eq $r2) {
		    return undef;
		} else {
		    return [$r1, $r2, $posn];
		}
	    }
	}
	return _arrays($r1, $r2, $accuracy, $posn) if $ref1 eq 'ARRAY';
	return _hashes($r1, $r2, $accuracy, $posn) if $ref1 eq 'HASH';
	$Test->diag("Don't know how to compare $ref1");
	return [$r1, $r2, $posn];
    } elsif (not defined $r1 and not defined $r2) {
	# both undefined so equal
    } else {
	# one undefined, one not
	return [$r1, $r2, $posn];
    }
}

sub _arrays {
    my ($a1, $a2, $accuracy, $posn) = @_;
    for( my $i = 0; $i < @$a1; $i++ ) {
	my $result = _structs($a1->[$i], $a2->[$i], $accuracy, $posn . "[$i]");
	return $result if defined $result;
    }
    return undef;
}

sub _hashes {
    my ($h1, $h2, $accuracy, $posn) = @_;
    my %keys = (%$h1, %$h2);
    foreach my $key (keys %keys) {
	my $result = _structs($h1->{$key}, $h2->{$key}, $accuracy, $posn . "{$key}");
	return $result if defined $result;
    }
    return undef;
}

sub _numeric {
    my ($v, $name) = @_;
    return ($v =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/) ? 1 : 0;
}

sub from_csv {
    my ($file) = @_;
    my @data;
    my $csv = new Text::CSV_XS;
    open(INFILE, "<", $file) or die "Unable to open \'$file\': $!\nStopped";
    while (<INFILE>) {
	chomp;
	my $ok = $csv->parse($_);
	if ($ok) {
	    my @row = $csv->fields();
	    push @data, [ @row ] if (@row);
	}
    }
    close INFILE;

    return \@data;
}

=head2 from_csv( filename )

Reads CSV file returning data as an array ref.

=cut

sub csv_to_sample {
    my $file = shift;
    my $data = from_csv($file);
    return array_to_sample($data);
}

=head2 csv_to_sample( filename )

Reads data from the specified CSV file and returns a hash with the same structure as Finance::Shares::Sample
data, i.e. open, high, low, close, volume and lx sub-hashes.

=cut

sub array_to_sample {
    my $data = shift;
    my (%open, %high, %low, %close, %volume, %lx, @dates);
    my $x = 0;
    foreach my $row (@$data) {
	my ($date, $open, $high, $low, $close, $volume) = @$row;
	$open{$date} = $open;
	$high{$date} = $high;
	$low{$date} = $low;
	$close{$date} = $close;
	$volume{$date} = $volume;
	push @dates, $date;
	$lx{$date} = $x++;
    }
    return { open => \%open, high => \%high, low => \%low, close => \%close, volume => \%volume, 
	     lx => \%lx, dates => \@dates };
}

=head2 array_to_sample( arrayref )

Given an array structured like a CSV file, it returns a hash with the same structure as Finance::Shares::Sample
data, i.e. open, high, low, close, volume and lx sub-hashes and dates array.

=cut

sub sample_to_csv {
    my ($sample, $file) = @_;
    my $open = $sample->{open};
    my $high = $sample->{high};
    my $low = $sample->{low};
    my $close = $sample->{close};
    my $volume = $sample->{volume};
    open DATES, '>', $file;
    foreach my $date (sort keys %$close) {
	my $o = $open->{$date} || '';
	my $h = $high->{$date} || '';
	my $l = $low->{$date} || '';
	my $c = $close->{$date} || '';
	my $v = $volume->{$date} || '';
	printf DATES '%s,%s,%s,%s,%s,%s%s', $date, $o, $h, $l, $c, $v, "\n";
    }
    close DATES;
    $Test->diag("results saved as '$file'");
}

=head2 sample_to_csv( sample, file )

Writes out Finance::Shares::Sample data so that it can be read by B<from_csv>.

=cut

sub show_lines {
    my ($s, @graphs) = @_;
    @graphs = qw(prices volumes cycles signals) unless @graphs;
    my $res = '';
    foreach my $graph (@graphs) {
	my @lines = values %{$s->{lines}{$graph}};
	@lines = sort { $a->{order} <=> $b->{order} } @lines;
	$res .= "$graph lines...\n" if @lines;
	foreach my $h (@lines) {
	    my $id = $h->{id};
	    my $show = $h->{shown} || 0;
	    my $order = $h->{order} || 0;
	    my $n = keys %{$h->{data}} || 0;
	    my $style = $h->{style};
	    my $sid = (ref($style) eq 'PostScript::Graph::Style') ? $style->id() : '';
	    $res .= "    $show $id ($n pts) $order $sid\n";
	}
    }
    return $res;
}

=head2 show_lines( sample )

Prints the ids of all known lines.
Returns a string which may be displayed with e.g. B<warn>.

=cut

sub show {
    $Data::Dumper::Indent = 1;
    return Data::Dumper->Dump(@_);
}

=head2 show( [values...], [names...] )

Calls Data::Dumper on values passed.
Returns a string which may be displayed with e.g. B<warn>.

=cut

sub show_deep {
    my ($var, $min, $sep) = @_;
    my $ref = ref($var);
    if ($ref eq 'HASH') {
	return show_hash($var, $min, $sep);
    } elsif ($ref eq 'ARRAY') {
	return show_array($var, $min, $sep);
    } else {
	return $var;
    }
}
	
=head2 show_deep( var [, min [, sep]] )

Recursively dumps hash or array refs, returning a string which may be displayed with e.g. B<warn>.

=over 8

=item var

The scalar variable to be printed.

=item min

A limit to the depth printed out.

=item sep

String used to seperate entries (between pairs, not within them).

=back

=cut

sub show_hash {
    my ($h, $min, $sep, $depth) = @_;
    $min = -1   unless defined $min;
    $sep = ', ' unless defined $sep;
    $depth = 0  unless defined $depth;
    return $h unless $min;
    my $res = '';
    if ($h and ref($h) eq 'HASH') {
	$res .= "\n" . ('  ' x ($depth)) if $depth;
	$res .= "{";
	my $entry = 0;
	foreach my $k (sort keys %$h) {
	    my $v = $h->{$k};
	    my $key   = defined($k) ? $k : '<undef>';
	    my $value = defined($v) ? $v : '<undef>';
	    $res .= $sep if $entry;
	    $res .= "$key=>";
	    if (ref($value) eq 'HASH') {
		$res .= show_hash($value, $min-1, $sep, $depth+1);
		$res .= ('  ' x ($depth));
	    } elsif (ref($value) eq 'ARRAY') {
		$res .= show_array($value, $min-1, $sep, $depth+1);
		$res .= ('  ' x ($depth));
	    } else {
		$res .= $value;
	    }
	    $entry = 1;
	}
	$res .= "}\n";
    } else {
	$res = $h;
    }
    return $res;
}

sub show_array {
    my ($ar, $min, $sep, $depth) = @_;
    $min = -1   unless defined $min;
    $sep = ', ' unless defined $sep;
    $depth = 0 unless defined $depth;
    return $ar unless $min;
    my $res = '';
    if ($ar and ref($ar) eq 'ARRAY') {
	$res .= "\n" . ('  ' x ($depth)) if $depth;
	$res .= "[";
	my $entry = 0;
	foreach my $v (@$ar) {
	    my $value = defined($v) ? $v : '<undef>';
	    $res .= $sep if $entry;
	    if (ref($value) eq 'HASH') {
		$res .= show_hash($value, $min-1, $sep, $depth+1);
		$res .= ('  ' x ($depth));
	    } elsif (ref($value) eq 'ARRAY') {
		$res .= show_array($value, $min-1, $sep, $depth+1);
		$res .= ('  ' x ($depth));
	    } else {
		$res .= $value;
	    }
	    $entry = 1;
	}
	$res .= "]\n";
    }
    return $res;
}

sub check_filesize {
    my ($psfile, $pssize) = @_;
    my %fs;
    my $filesizes = 't/filesizes';
    
    if (open(IN, '<', $filesizes)) {
	while (<IN>) {
	    chomp;
	    my ($size, $file) = m/^(\d+)\t(.+)$/;
	    $fs{$file} = $size;
	}
	close IN;
    }
    
    my $exists = $fs{$psfile};
    my $res = $exists ? ($fs{$psfile} == $pssize) : 1;
    $fs{$psfile} = $pssize;

    open(OUT, '>', $filesizes) or die "Unable to write to $filesizes : $!\n";
    while( my ($file, $size) = each %fs ) {
	print OUT "$size\t$file\n" if defined $file and defined $size;
    }
    close OUT;

    return $res;
}

=head2 check_filesize( filename, size )

This must be invoked from ../t as it uses a file 't/filesizes' to store the size each file should be.

=cut

1;
