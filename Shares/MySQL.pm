package Finance::Shares::MySQL;
our $VERSION = 1.03;
use strict;
use warnings;
use DBIx::Namespace 0.03;
use LWP::UserAgent;
use Carp;

# Prototypes of local functions only
 sub search_array ($$;$);
 sub end_of_block ($$);
    
# Global constants
our $agent_name = 'Finance::Shares::MySQL';
our @ISA = qw(DBIx::Namespace);
our %months = qw(jan 1 feb 2 mar 3 apr 4 may 5 jun 6 jul 7 aug 8 sep 9 oct 10 nov 11 dec 12);

=head1 NAME

Finance::Shares::MySQL - Access to stock data stored in a database

=head1 SYNOPSIS

    use Finance::Shares::MySQL;

    my $db = new Finance::Shares::MySQL(
	    hostname   => 'my_computer',
	    port       => 3306,
	    user       => 'myself',
	    password   => 'easy2guess',
	    database   => 'shares',
	    tries      => 3,
	    exchange   => 'NewYork',
	    start_date => '1980-01-01',
	    end_date   => '2002-12-31',
	);
	   
    my @rows = $db->fetch(
	    symbol     => 'MSFT',
	    name       => 'Microsoft',
	    exchange   => 'NASDAQ',
	    start_date => '1990-01-01',
	    end_date   => '1999-12-31'
	    mode       => 'offline',
	);
	
    $db->data_set('Company::Data', 'var1', 666);
    my $v = $db->data_get('Company::Data', 'var1');

=head1 DESCRIPTION

This module maintains stock quotes in a mysql database, fetching the data from the internet where necessary.
There is also support for storing company information.

=head2 Preparing the Database

Before using this module, the necessary permissions must be in place on the database server you wish to use.
This usually means logging on as root and giving the necessary password:

    root@here# mysql -u root -p mysql
    Password:

Within B<mysql> grant the user the necessary privileges (replace quoted items with your own):

    mysql> grant all privileges on "shares".* to "joe"
	   identified by "password";

Global file privileges and all privileges on the named database should be sufficient for Finance::Shares::MySQL
use.
    
=head2 Fetching Stock Quotes

Stock quotes are downloaded from Yahoo Finance in CSV format.  The default url seems to be able to download
historical quotes for all countries Yahoo keep data for, but a constructor option (C<url_function>) allows this to
be changed - to access a faster server, for example.

There are a lot of names used here and it can get a bit confusing.  Yahoo uses a symbol made from the exchange's
stock code and zero or more letters indicating the stock exchange.  These are a B<symbol> here.

    Symbol	Exchange	Stock
    ======	========	=====
    MSFT	NASDAQ		Microsoft
    BT.L	London		British Telecom
    MICP.PA	Paris		Michelin

The underlying database has a table name for each of these.  That is usually an unintelligable code used only
for low level access.  A B<user name> refers to the same table, see L</Namespace access>, they have C<Quotes::>
(note the leading space) prepended to the exchange and stock identifier.  The B<identifer> for each stock is the
most useful and can be anything you like.  It is usually used in conjunction with an identifier for the exchange
- user defined again.  So, in the example below, the data for Yahoo's 12126.PA might be stored under
' StockQuotes::Paris::Michelin'.  It would actually be held in a mysql table with a name like 't176'.

    Symbol	Exchange	Identifier
    ======	========	==========
    MSFT	NASDAQ		Microsoft
    BT.L	London		BT
    12126.PA	Paris		Michelin

The C<fetch> method encapsulates all the useful actions.  Depending on the mode (online, cache or offline) it will
fetch the quotes from the internet or the local database, returning a list of rows containing the data.  The
script B<fs_fetch> will fetch a series of quotes from the internet; B<fs_fetch_csv> additionally writing the data
to a CSV file.

=head1 CONSTRUCTOR

=cut

sub new {
    my $class = shift;
    my $opt = {};
    if (ref($_[0]) eq 'HASH') { $opt = $_[0]; } else { %$opt = @_; }
   
    my $o = new DBIx::Namespace(@_);
    bless( $o, $class );

    $o->{ua} = new LWP::UserAgent;
    $o->{ua}->agent("$agent_name/$VERSION " . $o->{ua}->agent);

    $o->{urlfn} = defined($opt->{url_function}) ? $opt->{url_function} : \&yahoo;
    $o->{tries} = defined($opt->{tries})        ? $opt->{tries}        : 3;
    $o->{exch}  = defined($opt->{exchange})     ? $opt->{exchange}     : 'US';
    $o->{end}   = defined($opt->{end_date})     ? $opt->{end_date}     : $o->today();
    $o->{start} = defined($opt->{start_date})   ? $opt->{start_date}   : $o->previous_day($o->{end});
    $o->{debug} = defined($opt->{verbose})      ? $opt->{verbose}      : 1;

    return $o;
}

=head2 new( options )

C<options> are passed to the base class.  See L<DBIx::Namespace/new> for details of the keys

    dbsource
    user
    password
    database

Keys recognized by this module are:

=head3 end_date

The end date to use when none is given.  (Defaults to today's date)

=head3 exchange

Provide a default setting so that it doesn't have to be entered repeatedly.  (Default: '')

=head3 verbose

Controls the number of warnings given. Can be 0, 1 or 2.

=head3 start_date

The default start date.  (Default:'2000-01-01')

=head3 tries

The number of attempts made to fetch a failed internet request.

=head3 url_function

This would be a function returning a fully qualified URL for fetching a series of up to 200 quotes using the same
format as http://finance.yahoo.com.  There should be no need to over-ride the default which works well with all
exchanges known to !Yahoo.  However, if it is needed the function should be a replacement for the C<yahoo> method.

=head1 MAIN METHODS

The following methods are specifically tailored to support a database of stock quotes.  It is used to fill
a Finance::Shares::Sample object, which in turn is used by almost all the other Finance::Shares:: modules.

The top level namespace is typically populated by exchanges (and a few internal names, all with leading spaces).
Each exchange namespace holds identifiers for all the known stock quoted there.  Each stock entry has two tables,
one for quotes and another for data.  

Most of these methods work with the quotes table, which has these fields:

    QDATE	The date
    OPEN	Opening price
    HIGH	Highest price on the day
    LOW		Lowest price on the day
    CLOSE	Closing price
    VOLUME	Number of shares traded

The data table provides some limited way of storing information about each share.  The variable name and the data
are stored as strings up to 255 characters long.  Its fields are:

    VARIABLE	The name
    VALUE	The content

=cut

sub fetch {
    my ($o, %f) = @_;
    croak "'symbol' must be specified\n" unless defined($f{symbol});
    $f{symbol} = uc($f{symbol});
    $f{symbol} =~ m/^(\w+)[^\w]?(\w*)$/;
    $f{name}       = $1        unless defined $f{name};
    $f{exchange}   = $2        unless defined $f{exchange};
    $f{exchange}   = 'US'      unless defined $f{exchange};
    $f{mode}       = 'cache'   unless defined $f{mode};
    $f{mode}       = 'offline' unless $o->{tries};
    $o->{exch}     = $f{exchange}   if defined $f{exchange};
    $o->{end}      = $f{end_date}   if defined $f{end_date};
    $o->{start}    = $f{start_date} if defined $f{start_date};
    $o->{tries}    = $f{tries}      if defined $f{tries};
   
    my $name = $o->quote_name($f{name}, $f{exchange});
    my $table;
    eval {
	$table = $o->table($name);
    };
    if ($@) {
	croak $@ unless ($@ =~ /^No SQL table/);
    }
    unless ($table) {
	$table = $o->stock_create($f{name}, $f{exchange});
	#my $data_name = $o->data_name($f{name}, $f{exchange});
	#$o->data_set($data_name, 'Symbol', $f{symbol});
    }

    my @rows;
    if ($f{mode} eq 'offline') {
	my $cols = 'Qdate, Open, High, Low, Close, Volume';
	my $query = 'qdate >= ? and qdate <= ? order by qdate';
	@rows = $o->sql_select("$cols from $table where $query", $o->{start}, $o->{end});
    } else {
	undef $table if $f{mode} eq 'online';
	@rows = $o->stock_fetch($f{symbol}, $o->{start}, $o->{end}, $table);
    }
    return @rows;
}

=head2 fetch( options )

This is the main method, called automatically by the constructor.  It acquires the stock quotes if it can,
returning an array of array refs each having the form:

    [ date, open, high, low, close, volume ]

C<options> are in hash key/value format, with the following keys recognized.

=over 12

=item symbol

The !Yahoo stock code whose quotes are being requested.

=item name

The identifier used for this particular stock.  If omitted it is derived from C<symbol>.

=item exchange

The identifier used for the stock exchange where C<symbol> is quoted.  If omitted it is derived from
C<symbol>, defaulting to 'US'.

=item start_date

The first day to fetch, in the form YYYY-MM-DD.

=item end_date

The last day to fetch, in the form YYYY-MM-DD.

=item mode

This controls how the quotes are processed.  Suitable values are:

=over 8

=item online

Stock quotes are fetched directly from !Yahoo without being stored in the database.

=item cache

If the requested quotes seem to be stored in the database they are returned from there.  Otherwise they are
fetched from the internet and stored before being returned.

=item offline

Quotes are only extracted from the database.

=back

=item tries

The number of attempts to be made fetching the quotes from the internet.  This defaults to the value given to the
constructor.  A value of 0 forces C<mode> to be 'offline'.

=back

Exceptions may be thrown.

=cut


sub data_set {
    my ($o, $name, $var, $value) = @_;
    croak "No variable name" unless $var;
    $value = '' unless defined $value;
    my $table;
    eval {
	$table = $o->table($name);
    };
    if ($@) {
	if ($@ =~ /^No SQL table/) {
	    my $fields = 'variable varchar(255) not null, ';
	    $fields   .= "value varchar(255), ";
	    $fields   .= "primary key(variable)";
	    $table = $o->create($name, $fields);
	} else {
	    croak;
	}
    }
    croak "No table for '$name'" unless $table;
    my $job = "replace into $table ( variable, value ) values ( '$var', '$value' )";
    $o->{dbh}->do( $job, "'data replace' failed" );
}

=head2 data_set( name, var [, value] )

=over 8

=item name

The fully qualified name of the table where C<var> is stored.

=item var

Variable name.

=item value

A string up to 255 characters long.

=back

Store a value against a variable name in a particular table.

Example

    my $db = new Finance::Shares::MySQL(...);
    my $name = $db->data_name('BSY', 'London');
    $db->data_set($name, 'Company', 
		    'British Sky Broadcasting');

=cut

sub data_get {
    my ($o, $name, $var) = @_;
    my $value;
    my $table = $o->table($name);
    if ($table and $var) {
	my @rows = $o->sql_select(qq(value from $table where variable = ?), $var);
	$value = $rows[0][0];
    }
    return $value;
}

=head2 data_get( name, var )

=over 8

=item name

The fully qualified name of the table where C<var> is stored.

=item var

Variable name.

=back

Return the string associated with a variable.

Example

    my $db = new Finance::Shares::MySQL(...);
    my $name = $db->data_name('BSY', 'London');
    my $company = $db->data_get($name, 'Company');

=cut

sub data_name {
    my ($o, $id, $exch) = @_;
    $id = '' unless defined $id;
    $exch = $o->{exch} unless defined $exch;
    croak "No identifier given" unless defined $id;
    return 'StockData::' . ($exch ? "${exch}::" : '') . $id;
}

=head2 data_name( id [, exch] )

Return a fully qualified user name leading to the data table for the stock code and exchange given.

=cut

sub quote_name {
    my ($o, $id, $exch) = @_;
    $id = '' unless defined $id;
    $exch = $o->{exch} unless defined $exch;
    croak "No identifier given" unless defined $id;
    return 'StockQuotes::' . ($exch ? "${exch}::" : 'US::') . $id;
}

=head2 quote_name( id [, exch] )

Return a fully qualified user name leading to the quotes table for the stock code and exchange given.
C<exch> defaults to 'US'.

=cut

=head1 SUPPORT METHODS

=cut


sub stock_create {
    my ($o, $id, $exch) = @_;
    
    my $name = $o->quote_name($id, $exch);
    my $fields = 'qdate date not null, ';
    $fields   .= 'open decimal(6,2), high decimal(6,2), low decimal(6,2), close decimal(6,2), ';
    $fields   .= 'volume integer, ';
    $fields   .= 'primary key(qdate)';

    return $o->create($name, $fields);
}

=head2 stock_create( id [, exch] )

Create a new blank table for the identified stock.

=over 8

=item id

The identifier used for this particular stock.

=item exch

The identifier used for the stock exchange where C<symbol> is quoted.

=back

Unlike the other C<stock_> methods this does not accept a mysql table.  Instead it returns one which may or may
not have been created on the way.

=cut

sub stock_fetch {
    my ($o, $symbol, $start, $end, $table) = @_;
    croak 'No stock code' unless $symbol;
    croak 'No start date' unless $start;
    croak 'No end date'   unless $end;
    my $start_day = $o->days_from_string( $start );
    my $end_day = $o->days_from_string( $end );
    croak 'end_date is before start_date' unless ($start_day <= $end_day);
    
    ## Identify any duplicates
    my %dates;
    if ($table) {
	my $cols = 'Qdate, Open, High, Low, Close, Volume';
	my $query = 'qdate >= ? and qdate <= ? order by qdate';
	my @rows = $o->sql_select("$cols from $table where $query", $start, $end);
	foreach my $ar (@rows) {
	    $dates{@$ar[0]} = [ @$ar ];
	}
    }
    
    ## Split into 200 day chunks
    $o->out(1, "Requesting $symbol from $start to $end");
    my ($sd, $ed);
    my ($total_fetched, $total_entered) = (0, 0);
    for ( $sd = $start_day, $ed = end_of_block($sd, $end_day); 
	  $sd <= $end_day; 
	  $sd = $ed + 1, $ed = end_of_block($sd, $end_day) ) {
	
	## Get file from internet
	my $func = $o->{urlfn};
	my $reqfile = &$func($o, $symbol, $sd, $ed);
	my $req = new HTTP::Request GET => $reqfile;
	my $sdstr = $o->string_from_days($sd);
	my $edstr = $o->string_from_days($ed);
	if ($table and $o->stock_present($table, $sdstr, $edstr)) {
	    $o->out(2, "     $symbol from $sdstr to $edstr already present");
	} else {
	    for (my $try = $o->{tries}; $try; $try--) {
		$o->out(2, "     $symbol from $sdstr to $edstr requested");
		my $res = $o->{ua}->request($req);
		if (not $res->is_success) {
		    $o->out(1, "     Unsuccessful request:\n\t\"$reqfile\"");
		} else {
		    my $data = $res->content();
		    pos($data) = 0;
		    my ($fetched, $entered) = (0, 0);
		    while ( $data =~ /^(.+)$/mg ) {
			my @fields = split (/,/, $1);
			# Identify lines beginning "31-Dec-02,..."
			my ($d, $m, $y) = ($fields[0] =~ /(\d+)-(\w+)-(\d+)/);
			if (defined($y)) {
			    $fetched++;
			    $m = lc($m);
			    $y = $y < 50 ? 2000 + $y : 1900 + $y;
			    my $date = $o->string_from_ymd( $y, $months{$m}, $d );
			    if ( not exists($dates{$date}) ) {
				if ($table) {
				    $fields[0] = "\"$date\"";
				    my $line = join(",", @fields);
				    $o->{dbh}->do( "replace into $table (qdate, open, high, low, close, volume)
					values($line)" );
				    $entered++;
				}
				$fields[0] = $date;
				$dates{$date} = [ @fields ];
			    }
			}
		    }
		    my $unit = ($fetched == 1) ? "date" : "dates";
		    my $msg = $table ? ",  $entered entered into table $table" : '';
		    $o->out(2, "     $fetched $unit fetched$msg");
		    $total_fetched += $fetched;
		    $total_entered += $entered;
		    last;   # try
		}
	    }
	}
    }
    if ($total_fetched) {
	my $unit = ($total_fetched == 1) ? "date" : "dates";
	$o->out(1, "$total_fetched $unit fetched,  $total_entered entered in total");
    }

    croak 'No quotes fetched' unless %dates;
    return sort { $a->[0] gt $b->[0] } values %dates;
}

=head2 stock_fetch( symbol, start, end [, table] )

Quote data is fetched from the internet for one stock over the given period.  The data is stored in a mysql table
if one is given.

=over 8

=item symbol

The stock code whose quotes are being requested.

=item start

The first day to fetch, in the form YYYY-MM-DD.

=item end

The last day to fetch, in the form YYYY-MM-DD.

=item table

The name of the mysql table where the data is to be stored.

=back

Data is returned as an array of array refs each having the form:

    [ date, open, high, low, close, volume ]

An exception is thrown if there was a problem.

=cut

sub stock_present {
    my ($o, $table, $start, $end) = @_;
    my $query = qq(select count(*) from $table where qdate >= '$start' and qdate <= '$end');
    my $days_found = 0;
    my $sth;
    if( $sth = $o->{dbh}->prepare($query) ) {
	if( $sth->execute() ) {
	    ($days_found) = $sth->fetchrow_array();
	} else {
	    $o->out(1, "ERROR - failed to execute query:\n\t\'$query\'");
	}
    } else {
	$o->out(1, "ERROR - failed to prepare query:\n\t\'$query\'");
    }
    $sth->finish();
    my $total_days = $o->days_from_string($end) - $o->days_from_string($start);
    my $fraction = $days_found/$total_days;
    #print "stock_present: $days_found/$total_days = $fraction\n";

    return $fraction > 19/28 ? 1 : 0;
}

=head2 stock_present( table, start, end )

Check whether an appropriate number of values exist in the specified table between the dates given.

Return 1 if seems ok, 0 otherwise.

=cut

sub days_from_string {
    my ($o, $str) = @_;
    return $o->sql_eval("to_days('$str')");
}

sub string_from_days {
    my ($o, $days) = @_;
    return $o->sql_eval("from_days($days)");
}

sub ymd_from_days {
    my ($o, $days) = @_;
    my $d = $o->sql_eval("dayofmonth(from_days($days))");
    my $m = $o->sql_eval("month(from_days($days))");
    my $y = $o->sql_eval("year(from_days($days))");
    return ($y, $m, $d);
}

sub ymd_from_string {
    my ($o, $str) = @_;
    my $d = $o->sql_eval("dayofmonth($str)");
    my $m = $o->sql_eval("month($str)");
    my $y = $o->sql_eval("year($str)");
    return ($y, $m, $d);
}

sub string_from_ymd {
    my ($o, $y, $m, $d) = @_;
    return sprintf ('%04d-%02d-%02d', $y, $m, $d);
}

sub today {
    my ($o) = @_;
    return $o->sql_eval("curdate()");
}

sub previous_day {
    my ($o, $date) = @_;
    return $o->sql_eval("date_sub( ?, interval 1 day )", $date);
}

sub debug {
    my ($o, $debug) = @_;
    $o->{debug} = $debug if defined $debug;
    return $o->{debug};
}

sub out {
    my ($o, $lvl, $str) = @_;
    print STDERR "$str\n" if $lvl <= $o->{debug};
}

sub yahoo {
    my ($o, $symbol, $start_day, $end_day) = @_;
    my $url = "http://table.finance.yahoo.com/table.csv";
    my ($year, $month, $day) = $o->ymd_from_days( $start_day );
    $url .= ("?a=" . $month . "&b=" . $day . "&c=" . $year);
    ($year, $month, $day) = $o->ymd_from_days( $end_day );
    $url .= ("&d=" . $month . "&e=" . $day . "&f=" . $year . "&s=$symbol");
    return $url;
}
# $block_end = end_of_block( $block_start, $max_end )
# Return the smaller of +200 weekdays or the end day

=head2 yahoo( obj, symbol, start, end )

=over 8

=item obj

The Finance::Shares::MySQL object.  This is needed to access date conversion functions.

=item symbol

The abbreviation used to identify the stock and exchange.  E.g. 'BSY.L' for BSkyB quoted in London.

=item start

The first quote date requested, in YYYY-MM-DD format.

=item end

The last quote date requested, in YYYY-MM-DD format.

=back

The default function for constructing a url.  This one accesses http://uk.table.finance.yahoo.com.  Obviously
targetted for the London Stock Exchange, it will fetch quotes from other exchanges.  Try it first before writing
a replacement.

Any replacement should accept the three strings above, and return a fully qualified URL.

Example

    yahoo('BA.L', '2002-06-01', '2002-06-30')

This would return (on a single line, of course)

    'http://table.finance.yahoo.com/table.csv?
		a=6&b=1&c=2002&d=6&e=30&f=2002&s=BA.L'

=cut

### PRIVATE FUNCTIONS

sub search_array ($$;$) {
    my ($ar, $value, $idx) = @_;
    $idx = 0 unless $idx;
    foreach my $rr (@$ar) {
	return @$rr if ($rr->[$idx] eq $value);
    }
    return ();
}
# =head2 search_array( array_ref, string, [index] )

# C<array_ref> should refer to an array of array references.  If C<index> is given, it is the position in the
# subarray where C<string> is expected to be.
#
# Return the sub-array (NOT ref) found or ().
#
# =cut

sub end_of_block ($$) {
    my ($sd, $end_day) = @_;
    my $ed = $sd + 275;	    # ~200 weekdays
    return ($ed < $end_day) ? $ed : $end_day;
}
# Return a suitable end-date for a quote.  
# Yahoo has a limit of 200 prices per request.

=head1 BUGS

Please report those you find to the author.

=head1 AUTHOR

Chris Willmot, chris@willmot.org.uk

=head1 SEE ALSO

L<Finance::Shares::Sample>.

There is also an introduction, L<Finance::Shares::Overview> and a tutorial beginning with
L<Finance::Shares::Lesson1>.

=cut

1;
