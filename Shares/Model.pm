package Finance::Shares::Model;
our $VERSION = 1.01;
use strict;
use warnings;
use Log::Agent;
use PostScript::File 1.00 qw(check_file);
use Finance::Shares::Support qw(
    $number_regex $field_split $field_join
    unique_name
    today_as_string check_dates is_date
    read_config deep_copy extract_list 
    name_join name_split
    out out_indent show show_deep
);
use Finance::Shares::Chart;
use Finance::Shares::MySQL;
use Finance::Shares::data;
use Finance::Shares::value;
use Finance::Shares::test;
use Finance::Shares::mark;

our %data_lines = qw(open 1 high 1 low 1 close 1 volume 1);

sub new {
    my $class = shift;
    my $argv  = shift || [];
    my %argh  = @$argv;

    my $o = {
	## Input
	# given or defaults
	
	config   => $argh{config},
	verbose  => $argh{verbose} || 1,
	filename => '',
	null     => '<none>',

	# user specification
	sources => [],
	stocks  => [],
	dates   => [],
	files   => [],
	charts  => [],
	groups  => [],
	samples => [],
	lines   => [],
	tests   => [],

	## Preparation
	# set up by constructor
	
	alias       => {},  # user spec 'names'

	# date fields
	dname   => [],
	dby     => [],
	dstart  => [],
	dend    => [],
	dbefore => [],
	dafter  => [],

	# sample fields
	sname   => [],
	scodes  => [],
	sdates  => [],
	slines  => [],
	ssource => [],
	sfile   => [],
	schart  => [],
	spage   => [],

	## Create objects
	# used by build()
	
	# file fields
	fname   => [],	    # the file name
	fpsf    => [],	    # PostScript::File
	fpages  => [],	    # page numbers shown in this file
	
	# page fields
	pname   => [],	    # in form "$sample/$stock/$date"
	psource => [],	    # may be Finance::Shares::MySQL
	plines  => [],	    # the sample's line entry
	pfsd    => [],	    # Finance::Shares::data
	pfsc    => [],	    # Finance::Shares::Chart

	known_codes => {},  # stock codes
	known_fns   => {},  # Finance::Shares::Function objects
	known_lines => {},  # Finance::Shares::Line objects
	scale       => [],  # lines that need scaling to their graphs
    };
    bless $o, $class;

    ## Configure
    my @cfg = read_config($o->{config});
    $o->collect_options( \@cfg );
    $o->collect_options( \@_ );
    $o->collect_options( $argv );
   
    #$o->ensure_default('files', $o->{filename} || 'default');
    $o->ensure_default('files',   {});
    $o->ensure_default('groups',  {});
    $o->ensure_default('samples', {});
    
    $o->prepare_dates;
    $o->prepare_stocks;
    $o->prepare_lines;
    $o->prepare_samples;

    return $o;
}

sub build {
    my $o = shift;

    $o->create_pages;
    $o->create_lines;
    $o->lead_times;
    $o->fetch_data;

    my $nlines = 0;
    my $npages = 0;
    my @filenames;
    my $files = $o->{fname};
    for (my $fp = 0; $fp <= $#$files; $fp++) {
	my $fname = $o->{fname}[$fp];
	out($o, 3, "Model::build pages for file $fp '$fname'");
	my $pages = $o->{fpages}[$fp];

	# build lines
	for (my $pp = 0 ; $pp <= $#$pages; $pp++) {
	    my $pname = $o->{pname}[$pp];
	    
	    out($o, 3, "Model::build lines on page $pp '$pname'");
	    my $fsd = $o->{pfsd}[$pp];
	    my $funcs = $o->{pfsls}[$pp];
	    foreach my $fns (@$funcs) {
		$nlines += $o->build_function($fns);
	    }

	    out($o, 3, "Model::build tests on page $pp '$pname'");
	    my $tests = $o->{ptests}[$pp];
	    foreach my $t (@$tests) {
		$nlines += $t->build();
		$t->finalize();
	    }
	}
	$o->scale_foreign_lines;
    }

    for (my $fp = 0; $fp <= $#$files; $fp++) {
	my $pages = $o->{fpages}[$fp];
	
	# build charts
	my $psf = $o->{fpsf}[$fp];
	my $multiple = 0;
	for (my $pp = 0 ; $pp <= $#$pages; $pp++) {
	    if ($o->{write_csv}) {
		my $fsd = $o->{pfsd}[$pp];
		my $file = $multiple ? '1' : $o->{write_csv};
		my $res = $fsd->write_csv( $file, $o->{directory} );
		out($o, 1, "CSV file ", ($res ? "'$res' saved" : "failed to save"));
	    }
	    my $fsc = $o->{pfsc}[$pp];
	    next if $o->{no_chart};
	    unless ($fsc->hidden) {
		out($o, 3, "Model::build chart for page $pp '",$o->{pname}[$pp],"'");
		$psf->newpage if $multiple;
		$multiple++;	# npages for this file only
		$npages++;	# total returned for testing
		$fsc->build;
	    }
	}

	# output file
	unless ($o->{no_chart}) {
	    my $tag = $o->{ffile}[$fp];
	    my $filename = $tag;
	    my $entry = $o->find_option('files', $tag);
	    if (ref $entry eq 'HASH') {
		$filename = $entry->{filename} if $entry->{filename};
	    }
	    $filename = $o->{filename} if $o->{filename};
	    push @filenames, check_file("$filename.ps", $o->{directory});
	    $psf->output( $filename, $o->{directory} );
	}
    }
    return ($nlines, $npages, @filenames);
}
# NB: $nlines is confused.
# For lines build_function() returns NEW lines;
# for tests build() returns REFERENCED lines, which may include existing ones.

###== RESOURCES =============================================================== 


sub collect_options {
    my ($o, $ar) = @_;
    return unless ref($ar) eq 'ARRAY';

    for (my $i = 0; $i <= $#$ar; $i += 2) {
	my $key = $ar->[$i];
	my $val = $ar->[$i+1];
	next unless $key;
	$key = lc($key);
	$key =~ s/s$//;
	if ($key eq 'stock'and $val and ref $val eq 'ARRAY') {
	    my $ar = $o->stock_file($val);
	    $val = [ 'default', $ar ] if $ar;
	}
	if (index('source stock date file chart group sample line test', $key) >= 0) {
	    # normal - array or single hash/string
	    my $option = $key . 's';
	    if (ref($val) eq 'ARRAY') {
		for( my $i = 0; $i < $#$val; $i += 2) {
		    $o->add_option($option, $val->[$i], $val->[$i+1]);
		}
	    } else {
		$o->add_option( $option, 'default', $val);
	    }
	} elsif (index('name', $key) >= 0) {
	    # special treatment for alias hash
	    if (ref($val) eq 'ARRAY') {
		for( my $i = 0; $i < $#$val; $i += 2) {
		    $o->{alias}{ $val->[$i] } = $val->[$i+1];
		}
	    }
	} elsif (index('start end', $key) >= 0) {
	    # cmd line dates.
	    $o->{$key} = $val if is_date($val);
	} elsif (index('verbose filename directory by show_value write_csv
		no_chart null', $key) >= 0) {
	    # cmd line options etc.
	    $o->{$key} = $val;
	}
    }
}
# NB: $key has no trailing 's', even if the option has one

sub add_option {
    my ($o, $option, $tag, $entry) = @_;
    my $array = $o->{$option};
    logdie("No option array for '$option'") unless ref($array) eq 'ARRAY';
    
    my $p;
    for( my $i = 0; $i < $#$array; $i += 2) {
	$p = $i, last if $array->[$i] eq $tag;
    }
    $p = @$array unless defined $p;
    
    $array->[$p] = $tag;
    $array->[$p+1] = $entry;

}


sub find_option {
    my ($o, $option, $tag) = @_;
    my $array = $o->{$option};
    logdie("No option array for '$option'") unless ref($array) eq 'ARRAY';
    for( my $i = 0; $i < $#$array; $i += 2) {
	next unless defined $array->[$i];
	return $array->[$i+1] if $array->[$i] eq $tag;
    }
    return undef;
}

sub add_resource {
    my ($o, $name, $value, $pp) = @_;
    my $array = $o->{$name};
    unless (defined $pp) {
	$pp = @$array;
	for (my $i = 0; $i <= $#$array; $i++) {
	    $pp = $i, last if $array->[$i] eq $value;
	}
	out($o, 7, "add_resource($name, $value) at $pp");
    }
    
    $array->[$pp] = $value;
    return $pp;
}
# $value added to end of $name array unless position $pp given

sub find_resource {
    my ($o, $name, $tag) = @_;
    my $array = $o->{$name};
    for( my $i = 0; $i <= $#$array; $i++) {
	return $i if $array->[$i] eq $tag;
    }
    return undef;
}

sub set_alias {
    my ($o, $short, $long) = @_;
    $o->{alias}{$short} = $long;
}

sub get_alias {
    my ($o, $short) = @_;
    return ($o->{alias}{$short} || $short);
}

sub ensure_default {
    my ($o, $option, $default) = @_;
    logdie("No option array for '$option'") unless ref($o->{$option}) eq 'ARRAY';

    unless ($o->{$option}[0]) {
	$o->{$option}[0] = 'default';
	$o->{$option}[1] = $default; 
    }
    return $o->{$option}[0];
}

###== PREPARATION ============================================================= 

sub prepare_samples {
    my $o = shift;

    my $sp = 0;
    my $array = $o->{samples};
    for (my $i = 0; $i < $#$array; $i += 2, $sp++) {
	my $tag = $array->[$i];
	my $hash = $array->[$i+1];
	my %s = $o->expand_groups($tag, $hash);
	my $val;
	
	$o->{sname}[$sp]  = $tag;
	$o->{spage}[$sp]  = $s{page};
	$o->{sfname}[$sp] = $s{file} || 'default';
	$o->{sfspec}[$sp] = $o->ensure_entry('files', $o->{sfname}[$sp]);
	
	if ($s{filename}) {
	    my $tag = $o->{sfspec}[$sp];
	    my $entry = $o->find_option('files', $tag);
	    $entry->{filename} = $s{filename} if ref $entry eq 'HASH';
	}

	$val = $s{source};
	$val = $o->ensure_entry('sources', $val) if defined $val;
	$val = $o->ensure_default('sources', '') unless defined $val;
	$o->{ssource}[$sp] = $val;
	
	$val = $s{stock};
	if (ref($val) eq 'ARRAY') {
	    foreach my $entry (@$val) {
		$o->{known_codes}{$entry}++;
	    }
	    $val = $o->ensure_entry('stocks', $val); 
	} elsif ($val) {
	    my $opt = $o->find_option('stocks', $val);
	    my $file = $o->stock_file($val);
	    if ($opt || $file) {
		$val = $opt || $file;
	    } else {
		$o->{known_codes}{$val}++;
	    }
	}
	$val = $o->ensure_default('stocks', '') unless defined $val;
	$o->{scodes}[$sp] = $val;
	
	$val = $s{date};
	if (ref $val eq 'ARRAY') {
	    foreach my $item (@$val) {
		unless (ref($item) eq 'HASH') {
		    my $fd = $o->find_option('dates', $item);
		    logdie "No date known as '$item'" unless ref($fd) eq 'HASH';
		    $item = $fd;
		}
		check_dates($item, $o->{start}, $o->{end}, $o->{by});
		$item = $o->ensure_entry('dates', $item);
	    }
	}
	$val = $o->ensure_entry('dates', $val) if defined $val;
	$val = $o->ensure_default('dates', {}) unless defined $val;
	$o->{sdates}[$sp] = $val;
	
	$val = $s{chart};
	$val = $o->ensure_default('charts', {}) unless $val;
	$o->{schart}[$sp] = $val;
	
	$val = $s{line};
	$val = [] unless $val;
	$val = [ $val ] unless ref($val) eq 'ARRAY';
	$o->{slines}[$sp] = $val;

	$val = $s{test};
	$val = [] unless $val;
	$val = [ $val ] unless ref($val) eq 'ARRAY';
	$o->{stests}[$sp] = $val; 
    }
}

sub prepare_lines {
    my $o = shift;

    my $array = $o->{lines};
    for (my $i = 0; $i < $#$array; $i += 2) {
	my $key = $array->[$i];
	my $hash = $array->[$i+1];
    
	my @list = ( extract_list($hash->{lines}), extract_list($hash->{line}) );
	$hash->{line} = \@list;
	delete $hash->{lines};
    }
}
# Ensure the user definition for each function has a 'line' entry that is an
# array ref, handling 'lines' variant.

sub prepare_dates {
    my $o = shift;

    my $d = 0;
    my $array = $o->{dates};
    for (my $i = 0; $i < $#$array; $i += 2, $d++) {
	my $key = $array->[$i];
	my $hash = $array->[$i+1];
	check_dates($hash, $o->{start}, $o->{end}, $o->{by}) if ref($hash) eq 'HASH';
    }
}

sub prepare_stocks {
    my $o = shift;
    my $stocks = $o->{stocks};
    return unless defined $stocks;
    
    my $i = 0;
    while ($i < $#$stocks) {
	my $key = $stocks->[$i];
	my $val = $stocks->[$i+1];
	
	my $ar = $o->stock_file($val);
	$val = $stocks->[$i+1] = $ar if $ar; 

	if (ref $val eq 'ARRAY') {
	    foreach my $entry (@$val) {
		$o->{known_codes}{$entry}++;
	    }
	} else {
	    $o->{known_codes}{$val}++;
	}

	$i += 2;
    }
}

sub stock_file {
    my ($o, $stock) = @_;
    return unless $stock;
    my @codes;
    
    open(SYMBOLS, '<', $stock) or return undef;
    while( <SYMBOLS> ) {
	chomp;
	s/#.*//;
	next if /^\s*$/;
	my @line = split /[,\s]+/;
	push @codes, @line;
    }
    close SYMBOLS;
    
    #print "Stocks=", join(',', @codes), "\n";
    return \@codes;
}

sub ensure_entry {
    my ($o, $option, $entry) = @_;
    if (defined $o->find_option($option, $entry)) {
	return $entry; 
    } else {
	my $type = $option;
	chop $type;	    # remove 's'
	my $name = unique_name( $type );
	$o->add_option($option, $name, $entry);
	return $name;
    }
}

sub expand_groups {
    my ($o, $name, $hash) = @_;
    my @all;

    # expand all 'group' entries to start of list
    my $group;
    while( my($key, $val) = each %$hash ) {
	if (lc($key) =~ /^group/) {
	    $group = $o->find_option('groups', $val);
	    logdie("Sample '$name' refers to unknown group '$val'") unless ref($group) eq 'HASH';
	    unshift @all, %$group;
	} else {
	    push @all, $key, $val;
	}
    }

    # use default if none specified
    unless ($group) {
	$group = $o->{groups}[1];
	unshift @all, %$group;
    }
    
    # standardize keys
    # NB: this silently folds plural and singular names to same key
    for (my $i = 0; $i < $#all; $i += 2) {
	my $key = $all[$i];
	$key = lc($key);
	$key =~ s/s$//;
	$all[$i] = $key;
    }

    return @all;
}
# given a sample tag and hash,
# returns list of all entries, including the contents of named groups.

###== CREATE OBJECTS ========================================================== 

sub create_pages {
    my $o = shift;
    out($o, 3, "Model::create_pages");
    out_indent(1);

    my $snames = $o->{sname};
    for (my $sp = 0; $sp <= $#$snames; $sp++) {
	my $sname = $o->{sname}[$sp];
	out($o, 3, "sample $sp '$sname'");

	# create source
	my $qname = $o->{ssource}[$sp];
	$o->{ssource}[$sp] = $o->create_source($qname) if $qname;
	out($o, 6, "ssource[$sp]=$o->{ssource}[$sp]");
	
	# create psfile
	my $fname = $o->{sfname}[$sp];
	my $fp = $o->find_resource('fname', $fname);
	$fp = $o->create_psfile($sp, $fname) unless defined $fp;

	# access stock code(s)
	my $cname = $o->{scodes}[$sp];
	my $codes = $o->find_option('stocks', $cname);
	$codes = $cname || '' unless $codes;
	$codes = [ $codes ] unless ref($codes) eq 'ARRAY';

	# access date(s)
	my $dname = $o->{sdates}[$sp];
	my $dates = $o->find_option('dates', $dname);
	logdie("Sample '$sname' has no date entry") unless $dates;
	$dates = [ $dates ] unless ref($dates) eq 'ARRAY';

	foreach my $code (@$codes) {
	    foreach my $date (@$dates) {
		my $dh = $date;
		unless (ref($dh) eq 'HASH') {
		    $dh = $o->find_option('dates', $date); 
		    $dname = $date;
		}

		check_dates($dh, $o->{start}, $o->{end}, $o->{by});
		my $pname = name_join($sname, $code, $dname);
		my $pp = $o->add_resource('pname', $pname);
		out($o, 3, "creating page $pp '$pname'");
		
		# create chart before data
		$o->{pfsc}[$pp] = $o->create_chart($pname, $sp, $code, $dh, $fp);
		$o->{pfsd}[$pp] = $o->create_data($pname, $sp, $code, $dh, $pp);
		out($o, 6, "page $pp\: date=$o->{pfsd}[$pp], chart=$o->{pfsc}[$pp]");

		push @{$o->{fpages}[$fp]}, $pp; 
		$o->{plines}[$pp] = $o->{slines}[$sp];
		$o->{ptests}[$pp] = $o->{stests}[$sp];
		$o->{pbefore}[$pp] = $dh->{before};
	   }
	}
    }
    out_indent(-1);
}

sub create_source {
    my ($o, $name) = @_;
    return if $name eq $o->{null};
    my $h = $o->find_option('sources', $name);
    return $h if ref($h) eq 'Finance::Shares::MySQL';
    return $h unless ref($h) eq 'HASH';

    $h->{verbose} = $o->{verbose} unless defined $h->{verbose};
    out($o, 4, "new Finance::Shares::MySQL");
    return new Finance::Shares::MySQL($h);
}
# create_source( name )
#
# name	    A {sources} identifier
#
# Before:   Resources must be set up.
# Process:  Create new mysql source from hash spec.
# After:    Returns either a Finance::Shares::MySQL object or the name of 
#	    a CSV file (or nothing).

sub create_psfile {
    my ($o, $sp, $fname) = @_;
    return if $fname eq $o->{null};
    my $filename = $fname;
    my $fh = $o->find_option('files', $fname);
    my $psf;
    if (ref($fh) eq 'PostScript::File') {
	# PSFile was given in user spec
	$psf = $fh;
    } else {
	# user spec was hash or filename
	$filename = $fh, $fh = {} unless ref($fh) eq 'HASH';
	$psf = new PostScript::File(
		headings  => 1,
		paper     => 'A4',
		landscape => 1,
		left      => 36,
		right     => 36,
		top       => 36,
		bottom    => 36,
		errors    => 1,
		%$fh,
	    );
    }
    out($o, 4, "new PostScript::File");

    # register new file
    my $fp = $o->add_resource('fname', $fname);
    $o->{ffile}[$fp]  = $filename;
    $o->{fpsf}[$fp]   = $psf;
    $o->{fpages}[$fp] = [];
    out($o, 6, "fpsf[$fp]=$psf");

    return $fp;
}
# create_psfile( name )
#
# name	    The {files} key identifying the user spec. for this
#	    postscript file.
#
# Before:   No requirements.
# Process:  A PostScript::File object is created, if necessary.
# After:    The PostScript::File described by the named resource
#	    is returned.


sub create_chart {
    my ($o, $pname, $sp, $code, $dh, $fp) = @_;
    out($o, 3, "Model::create_chart '$pname'");

    my $chartname = $o->{schart}[$sp];
    my $h;
    if ($chartname eq $o->{null}) {
	$h = { 
	    hidden => 1,
	};
    } else {
	$h = $o->find_option('charts', $chartname);
	logdie "No chart called '$chartname'" unless ref($h) eq 'HASH';
    }
    
    return new Finance::Shares::Chart(
	verbose => $o->{verbose},
	%$h,
	model   => $o,
	id      => $pname,
	file    => $o->{fpsf}[$fp],
	page    => $o->{spage}[$sp],
	stock   => $code,
	by      => $dh->{by} || '',
	# dates are set at build time
    );
}

sub create_data {
    my ($o, $pname, $sn, $code, $dh, $pn) = @_;
    out($o, 3, "Model::create_data '$pname'");
    
    ## prepare options
    my $name = name_join( $pname, 'data' );
    my $chart = $o->{pfsc}[$pn];
    my $h = {
	function => 'data',
	fsc      => $chart,
	source   => $o->{ssource}[$sn],
	stock    => $code,
	%$dh,
    };
 
    ## create data object
    my $fn = eval "Finance::Shares::data->new(verbose => $o->{verbose})";
    logerr("Can't create data object : $@"), return () unless $fn;
    $fn->add_parameters( %$h );

    $chart->add_data($fn);
    $o->{known_fns}{$name} = $fn;
    foreach my $tag ($fn->line_ids) {
	my $line_id = name_join($name, $tag);
	$o->{known_line}{$line_id} = $fn->line($tag);
	$o->set_alias($tag, name_join('data', $tag));
    }
    $o->add_option('lines', 'data', $h);

    return $fn;
}


sub create_lines {
    my $o = shift;
    out($o, 3, "Model::create_lines");
    out_indent(1);

    my $files = $o->{fname};
    for (my $fp = 0; $fp <= $#$files; $fp++) {
	my $pages = $o->{fpages}[$fp];
	for (my $pp = 0; $pp <= $#$pages; $pp++) {
	    my $pname = $o->{pname}[$pp];

	    # convert [ <regexp_pattern>,          <user_tag>, ... ]
	    # to      [ fullname1, fullname2, ..., fullname3,  ... ]
	    my $fullnames = $o->expand_line_names( $o->{plines}[$pp], $pname );
	    $o->{plines}[$pp] = $fullnames;
	    
	    # create each named line
	    my ($fsts, $larray);
	    my @lines;
	    foreach my $fqln (@$fullnames) {
		$larray = $o->create_line($fqln, $pp, $larray) unless $o->known_line($fqln);
		push @lines, $larray;
	    }

	    # add tests lines onto end of dependent FS::Lines list
	    ($fsts, $larray) = $o->create_tests( $o->{ptests}[$pp], $pp, \@lines);
	    $o->{ptests}[$pp] = $fsts;
	    $o->{ptfsls}[$pp] = $larray;
	    # Uncomment this if test lines aren't displayed automatically.
	    # BUT, the nlines total will be out :-(
	    #push @lines, $larray;
	    
	    $o->{pfsls}[$pp] = \@lines;
	}
    }
    out_indent(-1);
}

sub expand_line_names {
    my ($o, $ar, $pname) = @_;
    my (%hash, @array);
   
    foreach my $lname (@$ar) {
	$lname = $o->create_value($lname) if $lname =~ /$number_regex/;
	out($o, 7, "expand_line_names: '$lname' for page '$pname'");
	my @lines = $o->canonical_names($lname, $pname);
	logdie("Line '$lname' not recognized") unless @lines;
	out($o, 7, "'$lname' expanded to '", join(', ',@lines), "'");
	foreach my $linex (@lines) {
	    unless ($hash{$linex}) {	# remove duplicates
		$hash{$linex}++;
		push @array, $linex;	# maintain order given
	    }
	}
    }
	
    return \@array;
}
# expand_line_names( lnames, pname )
#
# lnames    an array ref holding a list of user given line tags, fqlns or
#	    regular expressions  
# pname	    full name of page
# 
# Before:   The {lines} entry can be a single string or an array ref
#	    containing such strings.  The strings can be one of these forms:
#		alias tag
#		tag/line
#		*/tag
#		*/tag/line
#		regex1/regex2/regex3/tag
#		regex1/regex2/regex3/tag/line
#	    where each regex is a regular expression matching:
#		regex1	sample tag(s)
#		regex2	stock tag(s)
#		regex3	date tag(s)
#	    They may also be '*' which is expanded to '.*' or '' which becomes
#	    the default tag for that position.
# Process:  Each string is expanded to a list of strings which refer to
#	    a specific line (data set).
# After:    {line} is an array ref containing names identifying unique function
#	    lines.  Returns the array ref.

sub canonical_names {
    my ($o, $line, $page) = @_;
    $line = $o->get_alias($line);
    out($o, 6, "canonical_names($line, $page)");
    out_indent(1);
    my @f = name_split $line;
    my (@x, @star);
    my $res;
    
    ## identify sections
    my ($fnchart, $fntag, $fnline);
    if ($f[3]) {
	# absolute
	$fnchart = name_join($f[0], $f[1], $f[2]);
	$fntag  = $f[3];
	$fnline = $f[4] || '';

	# fntag may be an alias
	my $alias = $o->{alias}{$fntag};
	if ($alias) {
	    my @g = name_split $alias;
	    $fntag   = $g[0];
	    $fnline  = $g[1] || '';
	}

    } else {
	# relative
	$fnchart = $page;
	$fntag   = $f[0];
	$fnline  = $f[1] || '';

	# might be sample/fntag[/line] for single page sample
#	my $alias = $o->{alias}{$fntag};
#	if ($alias) {
#	    $fnchart = $alias;
#	    $fntag   = $f[1];
#	    $fnline  = $f[2] || '';
#	}

	# no need to expand further if page and function known
	if ($o->find_option('lines', $fntag)) {
	    if ($fnline) {
		$res = name_join( $fnchart, $fntag, $fnline );
	    } else {
		# avoid trailing undef
		$res = name_join( $fnchart, $fntag );
	    }
	    out($o, 6, "found '$res' (relative)");
	    out_indent(-1);
	    return $res;
	}
    }

    my ($psample, $pstock,  $pdate) = name_split $page;
    my ($sample,  $stock,   $date)  = name_split $fnchart;
    # sample, stock, date may be tags, regexps, '*' or empty
    # fntag should be a lines tag, fnline is optional
    
    $sample = $psample unless $sample;
    $stock  = $pstock  unless $stock;
    $date   = $pdate   unless $date;
    out($o, 7, "processing '$sample/$stock/$date/$fntag/$fnline'");

    my ($xsample, $xstock, $xdate);
    $sample = '.*', $xsample = $psample if $sample eq '*';
    $stock  = '.*', $xstock  = $pstock  if $stock  eq '*';
    $date   = '.*', $xdate   = $pdate   if $date   eq '*';

    my @list;
    my @samples = $o->match_sample($sample, $xsample);
    #out($o, 1, "samples: ", join(', ', @samples));
    out_indent(1);
    foreach my $sample (@samples) {
	my @stocks = $o->match_stock($sample, $stock, $xstock);
	#out($o, 7, "stocks: ", join(', ', @stocks));
	my @dates  = $o->match_date( $sample, $date,  $xdate);
	#out($o, 7, "dates: ", join(', ', @dates));
	foreach my $code (@stocks) {
	    foreach my $date (@dates) {
		if ($fnline) {
		    $res = name_join( $sample, $code, $date, $fntag, $fnline );
		} else {
		    $res = name_join( $sample, $code, $date, $fntag );
		}
		push @list, $res;
	    }
	}
    }
    out_indent(-1);

    out($o, 6, "matches: ", join(', ', @list));
    out_indent(-1);
    return @list;
}

sub match_sample {
    my ($o, $sample, $except) = @_;
    $except = '' unless defined $except;
    my $array = $o->{samples};

    my $entry = $o->find_resource('sname', $sample);
    return ($sample) if $entry;
    
    my $regexp = eval { qr/$sample/; };
    logdie("Cannot compile sample '$sample' as regular expression : $@") unless defined $regexp;
    my @found;
    for( my $i = 0; $i < $#$array; $i += 2) {
	my $name = $array->[$i];
	next unless defined $name;
	next if $name eq $except;
	push @found, $name if $name =~ /$regexp/;
    }

    if (@found) {
	return @found;
    } else {
	logdie("Sample '$sample' not recognized");
    }
}

sub match_stock {
    my ($o, $sample, $given, $except) = @_;
    $except = '' unless defined $except;
    #out($o, 1, "match_stock($sample, $given, $except)");
    my $array = $o->{stocks};

    my $stocks = $given;
    my $sn = $o->find_resource('sname', $sample);
    my $tag = $o->{scodes}[$sn];	# stocks may be a tag, literal or array
    if ($tag) {
	if ($o->{known_codes}{$tag}) {
	    # sample entry is literal code
	    $stocks = $tag; 
	} else {
	    my $entry = $o->find_option('stocks', $tag);
	    if (ref($entry) eq 'ARRAY') {
		# sample entry is tag to list and given is one of these
		$stocks = $given;
	    } if ($o->{known_codes}{$entry}) {
		# sample entry is tag to literal code
		$stocks = $entry;
	    }
	}
    }
    #out($o, 1, "stocks=$stocks, tag=", $tag || '', ", given=", $given || '');
    
    if (ref($stocks) eq 'ARRAY') {
	# literal array given (must be list of codes)
	return @$stocks; 
    } else {
	my $entry = $o->find_option('stocks', $stocks);
	if ($entry) {
	    if (ref $entry eq 'ARRAY') {
		# tag indicating a list of codes
		return @$entry;
	    } else {
		# tag indicating single code
		return ($entry);
	    }
	}
    }

    # may be single literal or regexp
    my $regexp = eval { qr/$stocks/; };
    logdie("Cannot compile stock '$stocks' as regular expression : $@") unless defined $regexp;
    my @found;
    for( my $i = 0; $i < $#$array; $i += 2) {
	my $name = $array->[$i];
	my $list = $array->[$i+1];
	next unless defined $name;
	next if $name eq $except;
	if ($name =~ /$regexp/) {
	    if (ref $list eq 'ARRAY') {
		push @found, @$list;
	    } else {
		push @found, ($list);
	    }
	}
    }
    
    if (@found) {
	# was a regexp matching a tag
	return @found;
    } else {
	# assume a literal stock code
	return ($stocks);
    }
}

sub match_date {
    my ($o, $sample, $match, $except) = @_;
    $except = '' unless defined $except;
    my $array = $o->{dates};

    my $sn = $o->find_resource('sname', $sample);
    my $dates = $o->{sdates}[$sn];
    $dates = $match unless $dates;	# use page/fqln date if none given
    
    my $entry = $o->find_option('dates', $dates);
    return ($dates) if $entry;	# was a date tag

    # may be a regexp
    my $regexp = eval { qr/$dates/; };
    logdie("Cannot compile date '$dates' as regular expression : $@") unless defined $regexp;
    my @found;
    for( my $i = 0; $i < $#$array; $i += 2) {
	my $name = $array->[$i];
	my $list = $array->[$i+1];
	next unless defined $name;
	next if $name eq $except;
	push @found, @$list if $name =~ /$regexp/;
    }
    
    if (@found) {
	# was a regexp matching a tag
	return @found;
    } else {
	logdie("date '$dates' not recognized");
    }
}

sub create_line {
    my ($o, $fqln, $defaultpp, $arg) = @_;
    my @f     = name_split $fqln;
    my $page  = name_join @f[0 .. 2];
    my $pp    = $o->find_resource('pname', $page);
    $pp = $defaultpp unless defined $pp;
    my $fsc   = $o->{pfsc}[$pp];
    my $uname = $f[3]              || logdie("No user name for '$fqln'");
    my $fname = name_join $page, $uname;   # function name
    my $lname = $f[4]              || '';   # line id
    my $line;
    out($o, 3, "Model::create_line('$fqln')");
    out_indent(1);

    ## check for line
    my $fsl = $o->known_line( $fqln );
    if ($fsl) {
	out($o, 5, "using existing line '", $fsl->name, "'");
	out_indent(-1);
	return [ $fsl ];
    }
    
    ## check for function
    my $lh = $o->find_option('lines', $uname) || logdie("No line known as '$uname'");
    my $class = $lh->{function} || logdie("'$uname' has no function field");
    $class = $o->get_alias($class);
    my $fn = $o->known_function( $fname );
    
    unless ($fn) {
	## create function
	out($o, 5, "creating function '$fname'");
	$fn    = eval "Finance::Shares::$class->new(verbose => $o->{verbose})"
			|| logdie("Can't create function '$class' : $@");
	$o->declare_known_function( $fname, $fn );
	
	my $fh = deep_copy($lh);
	if ($class eq 'value' and ref($arg) eq 'ARRAY') {
	    $fh->{gtype} = $arg->[0]{gtype};
	    $fh->{graph} = $arg->[0]{graph};
	}
	$fh->{verbose} = $o->{verbose};
	$fh->{fsc}     = $fsc;
	$fh->{id}      = $uname;
	
	# expand names for initialize() 
	$fh->{line} = $o->expand_line_names( $fh->{line}, $page );
	
	$fn->add_parameters( %$fh );	# and suitable defaults
	
	## create dependent lines
	my $fullnames = $o->expand_line_names( $fn->{line}, $page );
	$fn->{line} = $fullnames;	# including lines set as defaults
	if (@$fullnames) {
	    my (@lines, $lref);
	    foreach my $fqln (@$fullnames) {
		$lref = $o->create_line( $fqln, $pp, $lref );
		push @lines, $lref;
	    }
	    $fn->{line} = \@lines;
	    out($o, 6, "Lines= ", $fn->show_lines, " created for '$fname'");
	}
	out($o, 5, "created line(s) '$fqln'");
    }

    ## finish
    my $lines = $fn->line_list( $lname );
    foreach my $line (@$lines) {
	$fsc->add_line($line);
	$o->ensure_known_line($line);
    }
    out_indent(-1);
    return $lines;
}
# create_line( name, pp, [, arg] )
#
# name	    Absolute line name
# pp	    Default page number to use if name not fully qualified
# arg	    Optional argument:
#		previous Line object (if any)
#
# Before:   Charts should be objects
# Process:  Recursively check that line object exists,
#	    creating function objects as required.
# After:    An array ref is returned holding one or more
#	    Finance::Shares::Line objects.

sub ensure_known_line {
    my ($o, $line) = @_;
    my $name = $line->name;
    return if $o->{known_lines}{$name};
    $o->declare_known_line( $name, $line );

    # add new line to page it appears on
    my @f     = name_split $name;
    my $page  = name_join @f[0 .. 2];
    my $pp    = $o->find_resource('pname', $page);
    my $fnlines = $o->{pfsls}[$pp];
    $fnlines= $o->{pfsls}[$pp] = [] unless defined $fnlines;
    foreach my $ar (@$fnlines) {
	foreach my $l (@$ar) {
	    return if $l == $line;
	}
    }
    push @$fnlines, [ $line ];
}
# Ensure dependent lines (which might be on a different page)
# are displayed when that page is built

sub create_value {
    my ($o, $value) = @_;
    my $username = unique_name( 'value' );
    out($o, 5, "Model::create_value() for '$value'");
    my $h = {
	function => 'value',
	value    => $value,
	uname    => $username,
	shown    => $o->{show_value},
    };
    $o->add_option('lines', $username, $h);
    return $username;
}
# create_value( value )
#
# value	    The number to be made into a line
#
# This patch allows {lines} resources to contain
# numbers.  This will not work if a number is the first
# dependent line tag.  Use as e.g.
#
#   lines => [
#	aaa => {
#	    function => 'greater_than',
#	    lines => ['bbb', 666],
#	}
#   ]
#
# A suitable lines entry is made and the tag is returned.

sub create_tests {
    my ($o, $test_opts, $pp, $fnlines) = @_;
    out($o, 3, "Model::create_tests for page $pp");
    out_indent(1);

    my %code;
    my $tests = $o->{tests};
    for( my $i = 0; $i < $#$tests; $i += 2) {
	my $tag = $tests->[$i];
	my $val = $tests->[$i+1];
	$code{$tag} = $val if ref($val) eq 'CODE';
    }

    my (@tests, @lines, %hash, @array);
    # note all lines already known to model
    foreach my $ar (@$fnlines) {
	foreach my $fsl (@$ar) {
	    $hash{$fsl}++;
	}
    }
    
    foreach my $tag (@$test_opts) {
	my (@mkA, %mkH, @lnA, %lnH);	# ensure unique line numbers within each test
	my $t = deep_copy $o->find_option('tests', $tag);
	next unless $t;
	my $ref = ref $t;
	if ($ref eq 'HASH') {
	    $t->{before} = $o->testprep_eval($tag, 0, $t->{before} || '', $pp, \@mkA, \%mkH, \@lnA, \%lnH);
	    $t->{during} = $o->testprep_eval($tag, 1, $t->{during} || '', $pp, \@mkA, \%mkH, \@lnA, \%lnH);
	    $t->{after}  = $o->testprep_eval($tag, 0, $t->{after}  || '', $pp, \@mkA, \%mkH, \@lnA, \%lnH);
	    push @tests, $o->create_test($tag, $t->{verbose}, $t->{before}, $t->{during}, $t->{after}, $pp, \@mkA, \@lnA, \%code);
	} elsif ($ref eq '') {
	    $t = $o->testprep_eval($tag, 1, "$t" || '', $pp, \@mkA, \%mkH, \@lnA, \%lnH);
	    push @tests, $o->create_test($tag, undef, undef, $t, undef, $pp, \@mkA, \@lnA, \%code);
	}
	push @lines, @lnA;		# collect lines so Model knows to draw them
    }

    # identify new lines referenced in tests
    foreach my $fsl (@lines) {
	unless ($hash{$fsl}) {
	    $hash{$fsl}++;
	    push @array, $fsl;	# maintain order given
	}
    }

    out_indent(-1);
    return (\@tests, \@array);
}

sub testprep_eval {
    my ($o, $tag, $during, $str, $pp, $mkA, $mkH, $lnA, $lnH) = @_;
    out($o, 6, "testprep_eval: tag=$tag, str=$str");
    out_indent(1);
    my $pname = $o->{pname}[$pp];
    my %vars;	# map tag to accessing code
    
    while ($str =~ /([\$\@])([^\s,;\)\}\]]+)/g) {
	my $vtype = $1;
	my $given = "$1$2";
	#warn "given = $given\n";
	my @subs;
	my @lines = $o->canonical_names($2, $pname);
	
	my $abort = 0;
	foreach my $line (@lines) {
	    my @f = name_split($line);
	    my $entry = $o->find_option('lines', $f[3]);
	    #warn "tag=$f[3], entry=", $entry || '<undef>', "\n";
	    $abort++, last unless $entry;
	    my $larray = $o->create_line($line, $pp);
	    $abort++, last unless $larray;

	    foreach my $fsl (@$larray) {
		my $uname = $fsl->name;
		#warn "fsl=$uname\n";
		my $n = $lnH->{$uname};
		unless (defined $n) {
		    push @$lnA, $fsl;
		    $n = $lnH->{$uname} = $#$lnA;
		}
		if ($entry->{function} eq 'mark') {
		    $fsl->is_mark(1);
		    my $mark = $fsl->function;
		    unless ($mkH->{$mark}) {
			push @$mkA, $mark;
			$mkH->{$mark}++;
		    }
		    $fsl->{data} = [];
		    if ($during) {
			push @subs, "\$_l_->[$n]{data}";
		    } else {
			out($o, 1, "ERROR: '$given'.  Marks only work in 'during' test phase");
		    }

		} else {
		    if ($during) {
			push @subs, "\$_l_->[$n]{data}[\$i]";
		    } else {
			push @subs, "\$_l_->[$n]";
		    }
		}
	    }
	}
	
	unless ($abort) {
	    $vars{$given} = ($vtype eq '@') ? '(' . join(',', @subs) . ')' : $subs[0];
	    #warn "\$vars{$given} = $vars{$given}\n";
	}
    }

    # replace line refs with code to access them
    while( my ($var, $val) = each %vars ) {
	$var =~ s/\$/\\\$/g;
	$var =~ s/\@/\\\@/g;
	$var =~ s/\*/\\\*/g;
	$var =~ s/\./\\\./g;
	$var =~ s/$field_join/$field_split/g;
	#warn "var=$var, val=$val";
	$str =~ s/$var/$val/g;
    }
    
    #warn "original str=$str\n";
    $str =~ s/value\(\s*\$_l_->\[(\d+)\]\{data\}\[\$i\]([^\)]*)\)/value(\$_l_->[$1]$2)/g;
    $str =~  s/mark\(\s*\$_l_->\[(\d+)\]([^\)]*)\)/mark(\$_v_->[$1], \$i, \$_l_->[$1]$2)/g;
    $str =~ s/call\(([^\),]*)([^\)]*)\)/call(\$_c_->{$1}$2)/g;
    #warn "substituted str=$str\n";
    
    out_indent(-1);
    return $str;
}

sub create_test {
    my ($o, $tag, $verbose, $before, $during, $after, $pp, $marks, $lines, $code) = @_;

    # create test object for this code string
    my $test = new Finance::Shares::test(verbose => $o->{verbose});
    $test->add_parameters(
	id      => $tag,
	fsc     => $o->{pfsc}[$pp],
	verbose => defined($verbose) ? $verbose : $o->{verbose},
	before  => $before,
	during  => $during,
	after   => $after,
	line    => $lines,
	mark    => $marks,
	code    => $code,
    );

    # collect dependent lines
    my @deps;
    foreach my $line (@$lines) {
	push @deps, $line unless $line->is_mark;
    }
	
    # set dependencies
    foreach my $mark (@$marks) {
	$mark->{test} = $test;
	$mark->{line} = [ \@deps ];
    }

    return $test;
}

###== BUILD =================================================================== 

sub lead_times {
    my $o = shift;
    out($o, 3, "Model::lead_times");
    out_indent(1);

    my $files = $o->{fname};
    for (my $fp = 0; $fp <= $#$files; $fp++) {
	my $pages = $o->{fpages}[$fp];
	for (my $pp = 0 ; $pp <= $#$pages; $pp++) {
	    my $name = $o->{pname}[$pp];
	    my $max = 0;
	    my $fnlines = $o->{pfsls}[$pp];
	    my %visited;
	    foreach my $ar (@$fnlines) {
		for (my $ln = 0; $ln <= $#$ar; $ln++) {
		    my $fsl = $ar->[$ln];
		    my $fn  = $fsl->function;
		    unless ($visited{$fn}) {
			$visited{$fn}++;
			my $lead = $fn->longest_lead_time();
			$max = $lead if $lead > $max;
		    }
		}
	    }
	    out($o, 6, "lead_time for page '$name' is $max");
	    my $data  = $o->{pfsd}[$pp];
	    my $given = $o->{pbefore}[$pp];
	    $data->{before} = defined($given) ? $given : $max;
	}
    }
    out_indent(-1);
}
# lead_times()
#
# Before:   All objects must have been built.
# Process:  Each page object is visited along every function
#	    path from every chart, to evaluate the greatest lead
#	    time required by the function calculations.
# After:    The Finance::Shares::data objects have reliable 'lead' values
#	    which can be used to establish first and last
#	    dates to fetch.

sub fetch_data {
    my $o = shift;
    my $files = $o->{fname};
    for (my $fp = 0; $fp <= $#$files; $fp++) {
	my $fname = $o->{fname}[$fp];
	my $pages = $o->{fpages}[$fp];
	for (my $pp = 0 ; $pp <= $#$pages; $pp++) {
	    my $pname = $o->{pname}[$pp];
	    my $fsd = $o->{pfsd}[$pp];
	    $fsd->build;
	}
    }	
}

sub build_function {
    my ($o, $array) = @_;
    out($o, 3, "Model::build_function");
    out_indent(1);
    
    my $line_count = 0;
    foreach my $fsl (@$array) {
	my $name = $fsl->name;
	out($o, 3, "Model::build_line '$name'");
	
	my $fn = $fsl->function;
	if ($fn->{built}) {
	    out($o, 7, "Model::build_line '$name' already built");
	    next;
	}

	out_indent(1);
	if (ref($fn->{line}) eq 'ARRAY') {
	    foreach my $line (@{$fn->{line}}) {
		$line_count += $o->build_function($line);
	    }
	}
	out_indent(-1);
	
	$fn->build;
	$fn->finalize;
	$line_count += $fn->lines;
	out($o, 6, "built '$name', $line_count line(s)");
    }

    out_indent(-1);
    return $line_count;
}
# build_line( array )
#
# array     An array ref holding Finance::Shares::Line 
#	    objects to be built
#
# Before:   All objects must exist and Finance::Shares::data objects
#	    must have all the information required to fetch
#	    the quotes.
# Process:  Each dependent line is built, then these lines are
#	    built.
# After:    The Finance::Shares::Line and all its dependent lines now
#	    have data ready for display.

sub mark_for_scaling {
    my ($o, $fsl) = @_;
    push @{$o->{scale}}, $fsl;
}

sub scale_foreign_lines {
    my $o = shift;
    out($o, 5, "Model::scale_foreign_lines()");
    out_indent(1);
    foreach my $fsl (@{$o->{scale}}) {
	$fsl->scale;
    }
    out_indent(-1);
}

###== SUPPORT METHODS ========================================================= 

sub null_value {
    return $_[0]->{null};
}

sub page_number {
    my ($o, $fsd) = @_;
    my $pfsds = $o->{pfsd};
    for (my $pp = 0; $pp <= $#$pfsds; $pp++) {
	return $pp if $pfsds->[$pp] == $fsd;
    }
    return undef;
}
## page_number( fsd )
#
# fsd	    FS::data object
#
# Return the model page using the given data set

sub page_name {
    my ($o, $pp) = @_;
    return $o->{pname}[$pp];
}

sub known_function {
    my ($o, $fname) = @_;
    return $o->{known_fns}{$fname};
}

sub declare_known_function {
    my ($o, $fname, $fsfn) = @_;
    return unless ref($fsfn);
    return unless $fsfn->isa('Finance::Shares::Function');
    $o->{known_fns}{$fname} = $fsfn;
}

sub known_line {
    my ($o, $lname) = @_;
    return $o->{known_lines}{$lname};
}

sub declare_known_line {
    my ($o, $lname, $fsl) = @_;
    return unless ref($fsl);
    return unless $fsl->isa('Finance::Shares::Line');
    $o->{known_lines}{$lname} = $fsl;
}
    
###== DEBUG METHODS =========================================================== 

sub show_option {
    my ($o, $option) = @_;
    my $array = $o->{$option};
    logdie("No option array for '$option'") unless ref($array) eq 'ARRAY';
    my $res = "Options for '$option':\n";
    for( my $i = 0; $i < $#$array; $i += 2) {
	$res .= "    $array->[$i] = $array->[$i+1]\n";
	$res .= show_deep($array->[$i+1], 1) if ref($array->[$i+1]);
    }
    return $res;
}
# Returns string for printing

sub show_resource {
    my ($o, $name) = @_;
    my $array = $o->{$name};
    my $res = "Array '$name':\n";
    for( my $i = 0; $i <= $#$array; $i++) {
	my $entry = $array->[$i];
	$res .= "   $i ";
	if (ref($entry) eq 'ARRAY') {
	    $res .= join(', ', @$entry);
	} else {
	    $res .= $entry;
	}
	$res .= "\n";
    }
    return $res;
}
# Returns a string for printing

sub show_aliases {
    my $o = shift;
    my $res = "Aliases:\n";
    foreach my $key (sort keys %{$o->{alias}}) {
	$res .= "    $key = '$o->{alias}{$key}'\n";
    }
    return $res;
}

sub show_known_functions {
    my $o = shift;
    my $res = "Known functions:\n";
    my @keys = sort keys %{$o->{known_fns}};
    foreach my $key (@keys) {
	my $fsfn = $o->{known_fns}{$key};
	$res .= "    $key => $fsfn\n";
    }
    return $res;
}
# Returns a string for printing

sub show_known_lines {
    my $o = shift;
    my $res = "Known lines:\n";
    my @keys = sort keys %{$o->{known_lines}};
    foreach my $key (@keys) {
	my $fsfn = $o->{known_lines}{$key};
	$res .= "    $key => $fsfn\n";
    }
    return $res;
}
# Returns a string for printing

sub show_model_lines {
    my $o = shift;
    
    my $res = '';
    my $files = $o->{fname};
    for (my $fp = 0; $fp <= $#$files; $fp++) {
	$res .= "file '$o->{fname}[$fp]':\n";
	my $pages = $o->{fpages}[$fp];
	for (my $pp = 0 ; $pp <= $#$pages; $pp++) {
	    $res .= "  page '$o->{pname}[$pp]':\n";
	    $res .= "    lines \$o->{pfsls}:\n";
	    my $funcs = $o->{pfsls}[$pp];
	    for (my $fn = 0; $fn <= $#$funcs; $fn++) {
		my $array = $funcs->[$fn];
		for (my $ln = 0; $ln <= $#$array; $ln++) {
		    my $fsl = $array->[$ln];
		    my $linename = $fsl->name;
		    $res .= "      [$pp][$fn][$ln] $linename\n";
		}
	    }
	    $res .= "    tests \$o->{ptfsls}:\n";
	    my $array = $o->{ptfsls}[$pp];
	    for (my $ln = 0; $ln <= $#$array; $ln++) {
		my $fsl = $array->[$ln];
		my $linename = $fsl->name;
		$res .= "      [$pp][$ln] $linename\n";
	    }
	    $res .= "\n";
	}
    }

    return $res;
}
# Map x-y-z in $fsm->{pfsls}[x][y][z] to Finance::Shares::Line objects
# Returns a string for printing

###== SUPPORT FUNCTIONS ======================================================= 

sub option {
    my $name = shift;
    my $val;
    for( my $i = 0; $i < $#_; $i += 2) {
	my $key = $_[$i];
	$val = $_[$i+1] if $key eq $name;
    }
    return $val;
}

__END__
###== DOCUMENTATION =========================================================== 

=head1 NAME

Finance::Shares::Model - Apply tests to series of stock quotes

=head1 SYNOPSIS

    use Finance::Shares::Model;

    my $fsm = new Finance::Shares::Model( @spec );
    $fsm->build();

=head1 DESCRIPTION

One or more graphs are built from a specification in the form of a list of
hash/array references.  Apart from a few configuration entries documented under
L<CONSTRUCTOR>, the specification deals with ten types of resource:

=over 8

=item sources

Declare where the price and volume data comes from.

=item charts

These determine the charts' features, and can have a large number of sometimes
deeply nested options.

=item files

Control how the charts are output.

=item stocks

Lists or individual stock abbreviations.

=item dates

These entries specify the time period considered and how frequently graph
entries occur.

=item samples

The heart of the model, these determine which stocks, dates, charts, lines etc.
are to be used to produce one or more chart pages.

=item groups

Named groups of C<sample> settings.

=item names

It is possible to use short aliases for function names, for example.

=item lines

These control how the data is processed and how the various functions are used.

=item tests

Segments of perl code invoking a variety of actions depending on programmed
conditions.

=back

To fetch any data, there must be a B<source> and a B<stock> code specified.
B<dates>, B<files> and B<charts> have suitable defaults, and B<groups> and
B<names> are optional.  Nothing much happens without specifying at least one
B<line> or B<test> and, of course, a B<sample> entry to bring them all together.

The examples and tests tend to show the resources in the same order because
they are easier to find that way.  But this is not a requirement - any order
will do.

=head2 The fsmodel Script

The normal way of using this module would be via the script F<fsmodel> which has
its own man page.  Although B<fsmodel> can fetch data and draw charts without
one, non-trivial usage requires a model specification - a perl file ending with
a list of resource definitions.

See L<Finance::Shares::Overview/Using the fsmodel Script> for how to set it up
and some examples to try.  Also see the manpage L<fsmodel> for further details.

=head2 Specification Format

A model is specified as a list of these resource definitions.  If nothing is
given to the constructor, a blank graph called F<default.ps> is output.  But
that isn't much use.

A minimal model might specify a source, with a stock and a date group.  This
would then just display the price and volume data.

B<Example>

    my @spec = (
	filename => 'hpq2',
	source => 'hpq.csv',
	stock  => 'HPQ',
	date   => {
	    start => '2003-04-01',
	    end   => '2003-06-30',
	    by    => 'weekdays'
	},
    );

The file F<hpq.csv> would hold daily quotes for Hewlett Packard from April 1st
to June 30th 2003 in CSV format.  The price and volume data will appear as two
graphs on the same page, saved as F<hpq2.ps>.

You will notice that most examples here terminate the hash/array definition with
a comma (,) rather than a semi-colon (;).  This is because they are part
of a specification B<list>.  The B<fsmodel> script expects a perl file with such
a list as the last item. It might be pages long, but it's still one list.

=head3 Keys and Tags

Typically, the entries are in either an array or a hash ref.  The array ref is
most common as it may hold any number of entries.  A specification may have any
number of blocks with the same key.  They are merged together with only the last
tag entry counting if there are duplicates.

B<Example>

    files => [
	small => {
	    width  => 400,
	    height => 500,
	},
	tall => {
	    landscape => 0,
	},
	letter => {
	    paper => 'US-Letter',
	},
    ],

Here three different PostScript file formats are specified.

Outer, system defined resource identifiers (like C<files>, here) will be referred to as
B<keys>, while the inner, user-chosen identifiers (small, tall, letter) are
B<tags>.

=head3 Singular and Plural

Generally, the keys identifying the resources can be either singular or plural
(e.g.  C<file> or C<files>).  Both forms may be used interchangeably.

Tags, on the other hand must always be used exactly as defined.  All identifiers
are case sensitive.

[C<line> and C<test> tags may become perl variables and so should be of that
form.  C<file> and some C<chart> tags may be in quotes and contain spaces, as
they are file names and graph titles.  Anomalies like this are noted as they
arise.]

=head3 Default Entries

The other, hash ref, format specifies a single entry which normally becomes the
default.  That is, it is used if a needed resource has not been specified.
Unlike the array ref form, there can only be one default, so only the last is
used if several hash refs for the same key are given.

B<Example>

    file => {
	landscape => 1,
    },

This declares a default entry which will be used if the B<sample> hasn't
specified a B<file> resource.  No tag is specified, but the module assigns
the tag C<default>.

Single default entries like this are purely a convenience.  If they are not
present, the first entry in the array format is used as the default instead.

There are a couple of cases where the tag name has a special meaning.

=over

=item defaults

If one of the array entries is given the tag C<default>, that is used instead of
the first entry.  

=item file names

For the C<files> resource, tags specify the file name to use.  The default file
name can be specified seperately using the C<filename> option.  (See
L<CONSTRUCTOR>.)

=back

=head3 Page Names

A B<page> refers to the chart, where all the graphs for a particular data set
are shown on the same page.

Mostly, functions use lines and data from their own chart page and return their
own results there too.  However, one of the motivations for this rewrite was to
allow functions to use data from other charts, something which was impossible in
the previous version.

Each page is created when a B<sample> specifies a B<stock> over a given B<date>
range.  This combination uniquely identifies the quotes to be graphed
and worked on.  The page name is made from these tags seperated by forward
slashes:

    <sample_tag> / <stock_tag> / <dates_tag>

e.g.

    shops/MKS.L/july

The output PostScript file may contain multiple pages.  There are two ways to
generate them.

Most straight-forward is the use of multiple B<sample> entries, each specifying
its own date and stock.  One advantage here is that pages can be individually
named.

    dates => [
	by_days => {
	    start => '2003-03-01',
	    end   => '2003-05-31',
	    by    => 'weekdays',
	},
	by_weeks => {
	    start => '2003-06-01',
	    end   => '2003-08-31',
	    by    => 'weeks',
	},
    ],
    
    samples => [
	one => {
	    stock => 'AZN.L',
	    dates => 'by_weeks',
	    page  => 'astra',
	},
	two => {
	    stock => 'GSK.L',
	    dates => 'by_weeks',
	    page  => 'glaxo',
	},
    ],

The names of the two pages would be

    one/AZN.L/by_weeks
    two/GSK.L/by_weeks

Alternatively multiple B<stocks>/B<dates> can be specified from a single sample.
This is more powerful, and is the mode used by B<fsmodel>.

    # dates as above
    
    sample => {
	stocks => [qw(AZN.L GSK.L SHP.L)],
	dates  => ['by_days', 'by_weeks'],
    },

The names of the six pages (3 stocks x 2 dates) would be

    default/AZN.L/by_days
    default/AZN.L/by_weeks
    default/GSK.L/by_days
    default/GSK.L/by_weeks
    default/SHP.L/by_days
    default/SHP.L/by_weeks

So how can these data sets be used?  

=head3 Fully Qualified Line Names

Function names are appended to page names, with optional line identifiers (if
the function produces several lines).  These would be fully qualified line names
(FQLN):

    one/AZN.L/by_weeks/avg
    one/AZN.L/by_weeks/bollinger/high
    
    default/AZN.L/by_days/data/close
    default/AZN.L/by_days/data/volume
    
B<line> entries for functions (like B<moving_average>) usually have a C<line>
field inside the specification which indicates the source data to use in their
calculations.  C<avg> above would be the tag for such a line specification.

Normally the line is referred to simply by its tag.  But when referring to
a line on a different page, the fully qualified name is needed.

So it would be possible to indicate AstraZenica's volume on GlaxoSmithKline's
chart in the following example.

    lines => [
	astra => {
	    function => 'moving_average',
	    period   => 3,
	    gtype    => 'volume',
	    line     => 'astra///data/volume',
	},
    ],
    
    samples => [
	astra => {
	    stock => 'AZN.L',
	},
	glaxo => {
	    stock => 'GSK.L',
	    line  => 'astra',
	},
    ],

A few things are worth noting.

=over

=item Tags are typed

The tag 'astra' can be used for both lines and samples without confusion.

=item Using defaults in FQLNs

The fully qualified line name is not written as

    astra/AZK.L/default/data/close

(although it may have been).  Provided there is no ambiguity, any of the entries
in a page/line name may be omitted.  Here 'astra' (the sample) has only one
stock entry and uses the default date option, so they may be left blank.

=item Compatable graph types

The line used has volume-sized numbers but, like most functions, moving_average
works with prices by default.  If it were used directly, the glaxo price graph
would either be scaled to include the foreign line or the new line would be
scaled to fit the host chart.  Neither is very useful, so it is a good idea to
include at least a C<gtype> (or C<graph>) entry in every line specification.

=back

=head3 Wild Cards

Some functions use more than one source line.  These are specified within an
array.

    lines => [
	comp1 => {
	    function => 'compare',
	    lines    => [qw( /AZN.L//data/close /GKN.L//data/close )],
	},
    ],

    sample => {
	stocks => [qw(AZN.L GKN.L)],
	line   => 'comp1',
    },

To avoid writing out a lot of similar FQLNs the sample, stock and date sections
of line/page names may be regular expressions.  Also a single '*' in
a field stands for 'all but this one'.  Some examples:

=over

=item '/.+N.L/.*/average'

This would match the 'average' line on a number of pages:

    default/AZN.L/by_days/average
    default/AZN.L/by_weeks/average
    default/GKN.L/by_days/average
    default/GKN.L/by_weeks/average

=item '*//'

Matches every sample except the one being evaluated.  Useful on a summary sheet
which doesn't have the relevant lines anyway.  The empty stock and date fields
assume that the 'other' samples all have these set.

=item '.*/.*/*'

Every sample, every stock and every B<other> date set.

=back

[B<NB:> This facility is not at all solid.  If you can make it work, fine.
If it fails, write out all the FQLN's by hand.  Look at the tests for patterns
that work.]

=head2 Sources

A C<source> entry specifies where the price and volume data comes from.  It can
be one of the following.

=over 8

=item array

The array ref should point to quotes data held in sub-arrays.

=item string

This should be the name of a CSV file holding quotes data.

=item hash

A hash ref holding options for creating a new Finance::Shares::MySQL object.

=item object

A Finance::Shares::MySQL object created elsewhere.

=back

To be much use there must be at least one source, and the hash ref is probably
the most useful.  See L<Finance::Shares::MySQL> for full details, but the top
level keys that can be used here include:

    hostname	    port
    user	    password
    database	    exchange
    start_date	    end_date
    mode	    tries

B<Example>

    sources => [
	database => {
	    user     => 'me',
	    password => 'Gu355',
	    database => 'mystocks',
	},
	test => 'test_file.csv',
    ],

=head2 Charts

These are the Finance::Shares::Chart options that control what the graphs look
like.  Throughout this document a C<chart> refers to a collection of grids (the
C<graphs>) that appear on the same PostScript page.

See L<Finance::Shares::Chart> for full details, but these top level sub-hash
keys may be used in a chart resource:

    bgnd_outline    background
    heading	    glyph_ratio
    show_breaks	    smallest
    heading_font    normal_font
    heading_size    normal_size
    heading_color   normal_color
    dpi		    key
    x_axis	    graphs

[B<NB:> Chart keys C<sample>, C<file> and C<page> are ignored as they are filled
internally.]

C<graphs> is a special array listing descriptions for the graph grids that will
appear on the page. Each graph sub-hash may contain the following keys, although
'points' is only for prices and 'bars' only for volumes.  Generally, C<gtype>
and C<percent> are essential.  C<gtype> must be one of C<price>, C<volume>,
C<analysis> or C<level>.

    gtype	    percent
    points	    bars
    y_axis	    layout
    show_dates
    
It is probably a good idea to pre-define repeated elements (e.g.
colours, styles) using perl variables as values in the hash or sub-hashes.

B<Example>

    my $bgnd = [1, 1, 0.95];
    ...
    
    chart => {
	dpi => 72,
	background => $bgnd,
	show_breaks => 1,
	key => {
	    background => $bgnd,
	},
	graphs => [
	    'Quotes' => {
		percent => 60,
		gtype   => 'price',
		points  => {
		    color => [0.7, 0, 0.3],
		},
	    },
	    'Trading Volume' => {
		percent => 40,
		gtype   => 'volume',
		bars  => {
		    color => [0.3, 0, 0.7],
		},
	    },
	],
    },

=head2 Files

The output is a collection of charts saved to a PostScript file.  Each hash ref
holds options for creating the PostScript::File object used.  Once it is
created, any charts using it will be added on a new page.

If the array form is used, it contains one or more named hash refs.  The tags
become the name of the file, with '.ps' appended.  

See L<PostScript::File> for full details but these are the more useful sub-hash
keys:

    paper	    eps
    height	    width
    bottom	    top
    left	    right
    clip_command    clipping
    dir		    reencode
    landscape	    headings
    png		    gs

B<Example>
    
    files => [
	'Food-Retailers' => {
	    dir => '~/models',
	    paper => 'A5',
	},
    ],

    samples => [
	sample1 => {
	    symbol => 'TSCO.L',
	    file   => 'Food-Retailers',
	    ...
	},
    ],

Here the Tesco sample will appear as a page in the file
F<~/models/Food-Retailers.ps>.  In this case, the C<file> B<sample> entry is the
default (the first in B<files>) and so could have been omitted.

Where more than one sample specifies the same file, they appear on different
pages within it, in the order declared.

=head2 Stocks

These are EPIC codes identifying public companies' share quotes.  The codes are
those used by B<!Yahoo> at L<http://finance.yahoo.com>.  Each tag may refer to
either a single code or a list enclosed within square brackets.

B<Example>

    stocks => [
	lloyds => 'LLOY.L',
	banks  => [qw(AL.L BARC.L BB.L HBOS.L)],
    ],

=head2 Dates

Each series of quotes must have at least a start and end date.  These entries
specify how the time axis is set up for each graph and which quotes are used for
the function calculations.

B<Example>

    dates => {
	start => '2003-01-01',
	end   => '2003-03-31',
	by    => 'weeks',
    },

The entries are hash refs with the following fields.

=over 8

=item B<start>

In YYYY-MM-DD format, this should be the first date we are interested in (but
see B<before>).  (Defaults to 60 periods before B<end>.)

=item B<end>

In YYYY-MM-DD format, this should be the last quote date (see B<after>).
(Defaults to today's date.)

=item B<by>

This specifies how the intervening dates are counted.  Suitable values are
C<quotes>, C<weekdays>, C<days>, C<weeks> and C<months>.  (Default: 'weekdays')

C<quotes> is the only choice which is guaranteed to have no undefined data.  But
then it has no relationship to time.  C<weekdays> is probably the closest,
except that it becomes obvious when data is missing.  

The rest use a proper time axis, with C<weeks> and C<months> using averaged
data.  If the dates axis is getting too crowded, these are a good way to cover
a long period without using too many data points.

=item B<before>

Many functions require a number of data items beforet their results are valid.
By default, this lead time is not displayed.  However, this allows the user to
override that value.  For example, 0 will specify no lead time - so all the data
is displayed and the lines begin when they can.

It is worth noting that the C<before> value is calculated from the line
specifications, before the quotes are fetched.  Any missing data will have to be
made up from the graphed dates.

=item B<after>

It is possible to specify a number of unused dates after the end of the data.
This might be used for extrapolating function lines into the immediate future.

=back

=head2 Samples

Pages are generated from B<sample> entries.  Defaults are generated for all
essential features, making a valid (though not always useful) model.  A sample
normally has one entry for each resource type; the entries being tags found in
the relevent resource blocks.

B<Example>

    samples => [
	one => {
	    source   => 'database',
	    chart    => 'blue_graphs',
	    file     => 'letter_format',
	    stock    => ['banks', 'financial'],
	    dates    => 'default',
	    lines    => ['slow_avg', '10day_lows'],
	    tests    => 'oversold',
	    
	    group    => '<none>',
	    page     => 'bank1',
	    filename => 'banks',
	},
    ],

There are a few things to note about this example.

=over

=item The tags

All of these values ('database', 'blue_graphs') are meaningless in themselves.
They should be tags in the appropriate resource block.  So the <stocks> resource
might include

    stocks => [
	banks => ['LLOY.L', 'HBOS.L', ... ],
	financial => ['AV.L', 'PRU.L', ... ],
	...
    ],

=item Singular and plural

For system defined keys (source, chart, stock etc.) a trailing 's' is optional.
Sometimes it is more natural to use the singular and sometinmes the plural, but
they are interchangeable.

=item Lists

Many B<sample> entries can take a list of tags within square brackets as well as
a single scalar.  E.g.

    stock  => 'STAN.L',
    stocks => ['STAN.L', 'HSBA.L'],

This makes no sense for C<source>, C<chart> and C<file> as there can be only one
of each.  However each chart can have many C<lines> and C<tests>.  

C<stocks> and C<dates> may also take multiple entries, but these are used to
generate a number of seperate data sets.  See L<Page Names>.

=item Defaults

If an entry is omitted the value 'default' is assumed (so the C<dates> entry
above was not really necessary).  Although defaults are filled predictably,
the system is quite complex - especially if multiple entries, default blocks,
groups and configuration files are all in use.  When in doubt, it is always
safer (though less lazy) to be explicit.

C<lines> and C<tests> are an exception.  No defaults are used.  If you want
a line or test, you have to specify it.  However, the system will automatically
include any dependent lines - you don't have to list them all.

=item Other entries

These other keys may appear within a B<sample> specification.

=over 10

=item group

See L<Groups> for details.

=item page

A short identifier used to 'number' the postscript pages.  It is intended to be
a number, letter, roman numeral etc.  but any short word will do.  PostScript
viewers should use this to identify each sheet.

=item filename

This is a convenience item allowing the user to specify individual filenames on
a 'per sample' basis, leaving the B<files> entry to be more generic.  It is
overridden by more global settings.

=back

=item Sample names

The sample tag, C<one>, is never used and can be anything.

=back

As a convenience, C<stocks> and C<dates> may be given directly instead of
setting up a resource entry with a tag.

B<Example>

    sample => {
	stock => 'HBOS.L',
	date  => {
	    start => '2003-09-01',
	    by => 'quotes',
	},
    },

=head2 Groups

It is quite likely that several samples will have many settings in common.
Rather than repeating them, it is possible to put them in a B<group>.

B<Example>

    sources => [
	import  => 'source.csv',
	dbase   => { ... },
    ],

    files => [
	summary => { ... },
	pages   => { ... },
    ],

    charts => [
	single => { ... },
	quad   => { ... },
    ],

    lines => [
	one   => { ... },
	two   => { ... },
	three => { ... },
	four  => { ... },
    ],

    groups => [
	main => {
	    file  => 'pages',
	    chart => 'quad',
	    lines => [qw(one two)],
	},
	meta => {
	    file  => 'summary',
	    chart => 'single',
	},
    ],

    samples => [
	marks   => { stock => 'MKS.L',  page => 'marks' },
	boots   => { stock => 'BOOT.L', page => 'boots' },
	dixons  => { stock => 'DXN.L',  page => 'dixons' },
	argos   => { stock => 'GUS.L',  page => 'argos' },
	totals  => { group => 'meta',   line => 'three' },
	summary => { group => 'meta',   line => 'four' },
    ],

C<group> provides shorthand for a group of settings, and makes editing
easier.  

C<page> is a kludge allowing individual pages to have their own page identifier.
It actually sets the PostScript::File 'page' label, but is included as
a B<sample> key as it typically changes with each sample.

=head2 Names

This provides an 'alias' facility.  For example, you might be fed up with typing
'moving_average' a million times.  So your config file might include the
following, allowing 'mov' to be used instead.

    names => [
	mov => 'moving_average',
    ],

This facility allows you to refer to the price data as C<close> for example,
instead of C<data/close> as it should be.  The built-in mappings are

    open    => 'data/open',
    high    => 'data/high',
    low	    => 'data/low',
    close   => 'data/close',
    volume  => 'data/volume'

As with the others, any number of resource blocks may be used as they are merged
together.  Where there are duplicates the last entry is used.

=over

[This is another facility that hasn't been well tested.  But if it doesn't work,
you can always copy & paste.  So far names are consulted for:

    function module names
    page names (i.e. aliases for 'sample/stock/date')

]

=back

=head2 Lines

This array ref lists all the functions known to the model.  Like the other
resources, they may or may not be used.  However, unlike the others, the
sub-hashes are not all the same format as they may control a wide range of
objects producing graph lines.

B<Example>

    lines => [
	grad1	 => {
	    function => 'gradient',
	    period   => 1,
	    style    => $fn_style,
	},
	grad_env => {
	    function => 'envelope',
	    percent  => 5,
	    graph    => 'analysis',
	    line     => 'grad1',
	    style    => $fn_style,
	},
	expo     => {
	    function => 'exponential_average',
	},
    ],

C<$fn_style> would probably be a hash ref holding L<PostScript::Graph::Style>
options.

There are three types of lines.

=head3 Data lines

These are built-in and never appear in a B<lines> block.  They all belong to the
function C<data> and the individual line tags are C<open>, C<high>, C<low>,
C<close> and C<volume>.  Treat them as reserved words.

=head3 Dependent lines

Most functions produce lines in this category.  They are defined in B<line>
blocks and usually show up as a line on a graph (though they may yield more
depending on the function).  As well as the C<function> field, they also must
have C<line> and either C<gtype> or C<graph> entries.  If these are omitted,
they usually default to closing prices (i.e. line = C<data/close> and gtype
= C<prices>).

=head3 Independent lines

These are defined in B<line> blocks in the usual way, but they have no lines
depending on them.  Important built-in examples are C<value>, which draws
horizontal lines and C<mark> which uses test code (see below) to fill the data
points.  More reserved words.

=head3 Common Entry Fields

The only requirement is that they must have a key, C<function>, whose value
holds the name of the method.  However, these keys are also common:

    graph	gtype
    key		line
    order	period
    shown	style

B<Example>

    lines => [
	avg => {
	    function => 'moving_average',
	    gtype    => 'volume',
	    line     => ['volume'],
	    period   => 20,
	    key      => '20 day average of Volume',
	    order    => 99,
	    style    => {
		bgnd_color => 0,
		line => {
		    inner_color  => [ 1, 0.7, 0.3 ],
		    outer_color  => 0.4,
		    inner_dashes => [ 12, 3, 6, 3 ],
		    outer_dashes => [ ],
		    inner_width  => 1.5,
		    outer_width  => 2.5,
		},
		point => {
		    color => [ 0, 0.3, 1.0 ],
		    shape => 'plus',
		    size  => 8,
		    width => 4,
		},
	    },
	},
    ],
	    
This example has an abnormally large C<style> entry in order to illustrate the
possible fields.  The default styles are designed to draw each line in
a different colour and often only need one or two fields specifying directly.

=head2 Tests

One of the original aims in writing these modules was to develop a suite that
would link stock market analysis with the power of perl.  Well, here it is - its
reason for existence.

Tests are segments of perl code (mostly in string form) that are eval'ed to
produce signals of various kinds.  There are three types of entry.

=over

=item Simple text

The simplest and most common form, this perl fragment is eval'ed for every data
point in the sample where it is applied.  It can be used to produce conditional
signal marks on the charts, noting dates and prices for potential stock
positions either as printed output or by invoking a callback function.

Don't worry - it is only compiled once, and the compiled code is repeated - so
it is just as efficient as running code in a script file.

=item Hash ref

This may have three keys, C<before>, C<during> and C<after>.  Each is a perl
fragment, compiled and run before, during and after the sample points are
considered.  C<during> is thus identical to L<Simple text>.

This form allows one-off invocation of callbacks, or an open-print-close
sequence for writing signals to file.

=item Raw code

These are the callbacks invoked by the previous types of perl fragment.

=back

See L<Finance::Shares::test> for full details, but here is an illustration from
the package testing to give some idea of the supported features.

B<Example>
    
    tests => [
	sub1 => sub {
	    my ($date, $high, $low) = @_;
	    print "$date\: $low to $high\n";
	},

	test1 => q(
	    mark($above, 300) if $high > $value or not defined $high;
	    call('sub1', $date, $high, $low) if $low >= 290;
	),
	
	test2 => {
	    before => <<END
		print "before.\\n";
		my \$name = "$filename.out";
		open( \$self->{fh}, '>', \$name )
		    or die "Unable to write to '\$name'";
END
	    ,
	    during => q(
		if ($close > $average and defined $average) {
		    mark($mark, $close);
		    my $fh = $self->{fh};
		    print $fh "close=$close, average=$average\n"
			if defined $close;
		}
	    ),
	    after  => qq(
		print "after.\\n";
		close \$self->{fh};
	    ),
	},
    ],

Some notes.

=over

=item Perl variables

Perl variables may be used normally provided you avoid the tags used for
B<lines> and B<tests>.  Variables with these names refer to the value of the
line/test at that time.

=item Persistence

A special hash ref C<$self> has several predefined variables.  It is available
to all the perl text, allowing variables set in one section to be available in
another - when calculating averages, for example.

=item Programming facility

The perl fragments are just text or code refs.  They would typically be
presented within a model spec file which B<fsmodel> invokes using B<do>.  It is
therefore possible to create the code from seperate files, 'here' documents or
quoted strings.  Don't forget to escape the '$' signs when using double-quoted
strings.

=back

=head1 CONSTRUCTOR

In addition to the resources covered in L<DESCRIPTION>, the following options
(in key => value form) may also be included in the model specification.  [These,
too, will be comma (not semi-colon) seperated.]

=over 8

=item by

Set a default value for how the dates are shown.  Suitable values are

    quotes  weekdays
    days    weeks
    months

=item config

The name of a file containing a (partial) model specification.

=item directory

If C<filename> doesn't have a directory component, this becomes the directory.
Otherwise the current directory is used.

=item end

Set a default value for the last date considered, in YYYY-MM-DD format.

=item filename

The name associated with the default file specification.  '.ps' will be appended
to this.

=item no_chart

Used by B<fsmodel>, this supresses any chart output if set to 1.

=item null

The string assigned to this will be read as meaning 'nothing'.  The following
example states that the sample has no stock code.  (Default: '<none>')

    null => '<nothing>',

    sample => {
	stock => '<nothing>',
	...
    },

=item show_values

Where a function requires more than one dependent line, any after the first may
be a number.  This is converted internally to a C<value> line which may or may
not be shown displayed.  

There is no facility for specifying the style of these lines, but setting
C<show_values> to 1 will show and 0 will hide them all.

=item start

Set a default value for the first date to be displayed, in YYYY-MM-DD format.

=item verbose

Control the amount of feedback given while the model is being run.

    0	silent
    1	default
    2	show eval'ed code in user tests
    
    3	debug model outline
    4	debug model including objects
    5	most methods, including Chart
    6	diagnostic, inc Functions
    7	everything

=item write_csv

This saves the sample data in CSV format.  It may be either a name for the CSV
file or '1', in which case a suitable name is generated.  If more than one
sample page exists, all subsequent pages will also be saved into seperate files.

=back

=head1 BUGS

Please let me know when you suspect something isn't right.  A short script
working from a CSV file demonstrating the problem would be very helpful.

In particular the regular expression/wild card matching doesn't work properly.

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

Other modules involved in processing the model include
L<Finance::Shares::MySQL>, L<Finance::Shares::Chart>.

Chart and file details may be found in L<PostScript::File>,
L<PostScript::Graph::Paper>, L<PostScript::Graph::Key>,
L<PostScript::Graph::Style>.

All functions are invoked from their own modules, all with lower-case names such
as L<Finance::Shares::moving_average>.  The nitty-gritty on how to write each
line specification are found there.

Core modules used directly by this module include L<Finance::Shares::data>,
L<Finance::Shares::value>, L<Finance::Share::mark> and L<Finance::Share::test>.

For information on writing additional line functions see
L<Finance::Share::Function> and L<Finance::Share::Line>.
Also, L<Finance::Share::test> covers writing your own tests.

=cut

