=head1 NAME

Finance::Shares::Overview - Outline of Finance::Shares modules

=head1 DESCRIPTION

=head2 Overview

This suite aims to provide Perl programmable support for analysing prices of
shares quoted on the world's stock exchanges.  It gets the quotes from
L<http://finance.yahoo.com>, storing them in a mysql database.  Calculations and
tests may then be applied to the data, in an attempt to derive some meaning from
the semi-chaos.

The process is controlled from a file holding a model specification.
L<Finance::Shares::Model> interprets this and uses L<Finance::Shares::Chart> to
produce graphs showing the results.

Stock quotes are fetched using L<Finance::Shares::MySQL> and held in
a L<Finance::Shares::data> object.  Functions like averages or trend
identifiers are applied to these data and the results used in tests.  Each model
can apply several tests to several samples.  When the tests are run signals may
be invoked highlighting interesting situations.  The intention is to use these
signals to drive a simulated portfolio which can be used in analysing risk.

=head2 Preparation

You will need mysql working on your system.  This package's tests and tutorials
use the 'test' database that comes with every mysql installation.  They also
expect a user called 'test' with 'test' as the password.

To set this up, as root, fire up the mysql client and declare the user:

  # mysql
  Welcome to the MySQL monitor.  Commands end with ; or \g.
  Your MySQL connection id is 3 to server version: 3.23.52-Max-log

  Type 'help;' or '\h' for help. Type '\c' to clear the buffer.

  mysql> grant all privileges on test.* to 'test'
      -> identified by 'test';

  Query OK, 0 rows affected (0.15 sec)

B<NOTE:> There is always a database called 'test', so you don't need to create
it.  However, if you've chosen to use a different name you will need
to give the command C<create database db_name;> as well.

=head2 Running Models

=head3 Configuration file

There are a few examples in the F<models> directory of the distribution.  Before
running them, you might find it useful to set up a configuration file.  By
default, this is expected at

    ~/.fs/default.conf

Alternatively, it can be specified from the command line.

Configuration files have just the same elements as model specification files,
but usually only specify commonly used settings.  F<models/default.conf> is an
example.

=head3 Using the fsmodel Script

A script, F<fsmodel> should be available on your system.  Help is available with
either

    fsmodel --help
    man fsmodel

If the preconditions are met, the following command lines should produce
PostScript files (*.ps) which may be printed or viewed using a PostScript viewer
such as B<gv> or B<KGhostView>.

=head3 Conditions

=over

=item B<mysql> has been set up as in L</Preparation> above.
    
=item There is an open internet connection.

=item F<models/default.conf> has been copied to F<~/.fs/default.conf>.

=item The command is given from the distribution top level directory.

=back

=head3 Command lines

    fsmodel --model=models/greater MSFT

    fsmodel --model=models/less --file=less GSK.L AZN.L

    fsmodel -m models/compare -s stocks/FTSE-media -f media
    
    fsmodel -m models/convergence -s stocks/FTSE-mining -v 3

The system has successfully handled around 100 pages, so it should be OK with
useable numbers of stocks.
    
=head2 Handling PostScript

L<PostScript::File> is used to output all charts in PostScript format.
Originally this was because I couldn't find any software that printed A4 sized
charts with enough accuracy and detail to scribble lines on.  In practice,
I don't print them out nearly as often as they are viewed on screen, but it is
good to be able to do both.  This doesn't sit particularly well with the web
interface, but programs like B<pstill> can convert the output to PDF easily
enough.  To convert F<chart.ps> to Adobe Portable Document Format:

    pstill -o chart.pdf chart.ps

Don't forget that most browsers can be configured to do something useful with
files in application/postscript MIME format, possibly by nominating B<pstill> as
a helper program.

It is also worth investigating B<GhostScript> which is available for a wide
variety of platforms.  For example, the following command (on a single line)
will convert the file F<chart.ps> to Portable Network Graphics file
F<chart.png>.

    gs -q -dBATCH -sDEVICE=png16m \
	-sOutputFile=chart.png chart.ps

Ghostscript is freely available from Artifex Software, at
L<http://ghostscript.com> or from the Free Software Foundation at
L<ftp://mirror.cs.wisc.edu/pub/mirrors/ghost/gnu/current/>.

Note that B<gs> will also work as a filter.  PostScript might take a bit more
work than producing graphs directly, but all the advantages of vector graphics
are maintained.  As well as producing the generic printer format,
L<PostScript::File> can also output PNG files (for those applications that
require bitmapped graphics) and EPS files (for embedding directly in other
documents).

=head2 Support Modules

Each graph line is provided by its own module.  These are some of the functions
available.

L<Finance::Shares::Function> has instructions and examples showing how to extend
the suite by writing your own function modules.

=head3 Miscellaneous Support

These are generally used in more complex functions.

=over

=item mark

Used to specify the style of chart lines, points or bars under program control.

=item value

Place a visible horizontal line identifying a particular Y axis value.

=item gradient

Smoothed rate of change.

=item momentum

Shows how a measure changes between now and N days ago.

=item rate_of_change

Where 'momentum' is a difference, this is a ratio.

=back


=head3 Averages

Calculating the mean of a series of values within one line or the same value
across a series of lines.

=over

=item moving_average

The normal workhorse.

=item exponential_average

A variation which takes all previously known data into some account.

=item weighted_average

A moving average which has most recent values more heavily weighted.

=item multiline_mean

Calculates the average of a number of lines.

=back


=head3 Comparisons

Relate one line to another.

=over

=item compare

Express one or more lines relative to some base line used for comparison.

=back

C<greater_than>, C<greater_equal>, C<less_than> and C<less_equal> are a leftover
from version 0 and are included because they were an early part of the test
suite.  They are depreciated in favour of writing the tests directly.

=head3 Bands and Ranges

Functions identifying boundaries around the distributed values.

=over

=item highest

A trace of N-day highs.

=item lowest

A trace of N-day lows.

=item percent_band

Produces two lines, N percent above and below a source line.

=item bollinger_band

Produces two lines bounding typically 2 standard deviations above and below a
source line.

=back


=head3 Compound Functions

These typically use some other (hidden) function in their calculations.

=over

=item on_balance_volume

Give some indication of buying and selling pressure.

=item oversold

Identify when the rate of change is unusually high.

=item undersold

Identify when the rate of change is unusually low.

=item historical_highs

Show how long since some line was as high as the current value.

=item historical_lows

Show how long since some line was as low as the current value.

=item is_falling

Shows 'high' when the source line is decreasing.

=item is_rising

Shows 'high' when the source line is increasing.

=back


=head2 Changes Since Version 0

Version 1 is more or less a complete re-write; very little of the original code
remains.  The aim has changed.  Version 0 was attempting to become a toolkit of
modules that could be used to build your own stock analysis system.  It seems
that this general aim is not possible as the modules have to make assumptions
about the running environment.  [However, see L<http://geniustraders.org> for
a well developed (and more complex) trading system written in Perl which is well
worth a look.]

This solution provides an engine running a simulation from a specification file.
This file usually includes user perl code to be executed before, during and/or after
the run.  The code typically makes use of the graph functions and may write to the
graphs as well as invoke callbacks.

=head3 Declarative specifications

This suite has been developed to be more declarative than procedural.  Version
0 used a model specification, but the lines and tests had to be given in the
right order.

Now the model specification describes the results wanted, rather than the
processes to be carried out.  For example, Only top level lines or tests need to
be specified in a C<sample>.  The model engine infers what is needed and the order of
calculation from the specification and code fragments.

=head3 Different resources

C<sources>, C<files>, C<charts>, C<groups> and C<samples> are much the same.
But two others have been added, supporting a variety of named C<dates> and
C<stocks>.

C<functions> has been renamed C<lines> because that's what they mostly produce.
However, it is strictly inaccurate and may be confusing.

The C<tests> have either disappeared or become C<lines>.  C<signals> - the
distinguishing feature of the old tests - have disappeared altogether.  Instead
the new C<tests> are code fragments, giving much more flexibility and power.
Builtin functions now support things like chart marks, files and messages.

=head3 More scope for defaults

It is now possible to have the specification split over several files.  One of
which is a configuration file providing defaults or a complete model - as you
choose.

The resource names are more flexible, resource blocks can appear many times and
earlier default values can be overridden.

One of the configuration features is the introduction of user-defined aliases
- currently only used for function names, which are often rather long.

=head3 Programmable tests

Probably the most useful development is the use of code fragments or imported
callbacks which can be invoked before, during or after a model is run.  The
'during' fragment is visited at every data point, when a variety of data is made
available, including the value of all other lines.

Code fragments can be as large as you wish - complete files using additional
modules.  Callbacks or internal functions can be invoked conditionally within
your code, replacing the old C<signals>.

The line functions supporting this paradigm are rather different (See L</Support
Modules>).  All of the lines producing logical output (e.g. C<greater_than>,
C<and>) have gone.  Functions providing statistical measures (e.g. C<maximum>,
C<standard_deviation>) are provided, but are more often used to access the
single value they calculate.

=head3 Multiple pages

The previous version could produce PostScript files with several charts, but
they were completely seperate models.

It is now possible to produce several (possible related) charts and refer to one
stock model from another.  For example, it was previously impossible to compare
stock prices with a group average.  This can now be done.

=head3 Fully Qualified Line Names

If charts can interact, there must be some way to specify the same line on
different charts.  A chart is specified as a unique combination of C<sample>,
C<date> and C<stock> code.  The chart (or page) name qualifies the line name, in
the same way that a spreadsheet sheet name may qualify a cell range.

In addition, wildcards and regular expressions can be used to specify the same
line on particular pages, every line on a page, or even a line on 'every page
except this one'.

=head3 Graph layout

The graph types have been renamed.  C<price> and C<volume> types are the same,
but C<cycles> are now called C<analysis> and C<tests> have been renamed
C<levels>.  This is because the C<analysis> graphs are more flexible than before
and there are no more C<tests> to present output for.

In version 0, the graphs that could appear on a chart were fixed.  Now any
number of any graph type can appear in any order, with the date axis presented
on any or all of them.  As before, charts don't need to be specified as they
will be created automatically; but now the defaults are tailored to colour
output rather than defaulting to the lowest common denominator.

One major limitation of the old layout was that there was never enough space for
the Key panel.  To overcome this, there is now only one Key panel per page.  All
lines from any chart appear there.

It is possible to control the order of the lines explicitly, if you wish,
bringing some to the front and others to the back.

There are a few refinements to the graphs themselves.  As well as OHLC and close
marks, candles are now supported, both in monochrome and two colour versions.
The default styles for lines have been improved to the extent that style
specifications can be ignored if you wish.

In addition, the drawing order of lines is under complete user control.  It is
even possible to place them <behind> the data (by giving a negative value).

=head3 Alternative output

As well as the original PostScript, it is now possible to have graphs output in
PNG format.  These are (of course) always inferior quality, but often more
useful.

It is also possible to output the graphs in a CGI-compatible format.  One of the
motivations for driving the model from a single data structure was to simplify
CGI input.  No work has been done on this as yet, however.

=head3 Test driven development

There are many more tests in this package.  This reflects my increased use of
test driven development (well, a modified version I find useable).  By including
a batch of significant regression tests, it should be easier for others to
extend the code.

A couple of less helpful side effects of TDD, though.  First, the development is
a bit ad hoc.  This means that code is less regular than I would normally like
it - with more potential for errors.

Secondly, by the nature of things, the tests define what might be expected to
work.  Stray far from the tests and all hell breaks loose.  It will be
interesting to see if this improves.  

In the meantime, I recommend taking a close look at the F<t> and F<models>
directories.  Most tests beyond t/100.t have output files and give some idea of
the features available, but look at the example models for format.

=head1 AUTHOR

Chris Willmot, chris@willmot.org.uk

=head1 SEE ALSO

Have a look at the tests in the F<t> directory of the distribution.  The charts
produced will give you a good idea of the kind of thing this suite does.

F<fsmodel> is the main script, using L<Finance::Shares::Model> - see that man
page for details. 

=cut

