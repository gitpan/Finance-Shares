use ExtUtils::MakeMaker;

my $abstract = <<END;
=head1 NAME

Finance::Shares - Applying tests to share quotes

END

WriteMakefile(
    NAME	  => 'Finance::Shares',
    VERSION	  => '1.05',
    ABSTRACT      => $abstract,
    AUTHOR        => 'Christopher Willmot <chris@willmot.org>',
    NORECURS      => 1,
    PREREQ_PM	  => { 
	'Pod::Usage'		    => 0,
	'Date::Calc'                => 0,
	'Text::CSV_XS'              => 0,
	'LWP::UserAgent'            => 0,
	'Log::Agent',		    => 0,
	'DBIx::Namespace'           => 0.03,
	'PostScript::File'	    => 1.01,
	'PostScript::Graph::Bar'    => 0.03,
	'PostScript::Graph::Key'    => 1.01,
	'PostScript::Graph::Paper'  => 1.01,
	'PostScript::Graph::Style'  => 1.01,
	'PostScript::Graph::XY'	    => 0.04,
    },
    EXE_FILES => ['fsmodel'],
    PM	=> {
	'Shares/Chart.pm'	=> '$(INST_LIBDIR)/Shares/Chart.pm',
	'Shares/Code.pm'	=> '$(INST_LIBDIR)/Shares/Code.pm',
	'Shares/Function.pm'	=> '$(INST_LIBDIR)/Shares/Function.pm',
	'Shares/Line.pm'	=> '$(INST_LIBDIR)/Shares/Line.pm',
	'Shares/Model.pm'   	=> '$(INST_LIBDIR)/Shares/Model.pm',
	'Shares/MySQL.pm'	=> '$(INST_LIBDIR)/Shares/MySQL.pm',
	'Shares/Overview.pm'	=> '$(INST_LIBDIR)/Shares/Overview.pm',
	'Shares/Support.pm'	=> '$(INST_LIBDIR)/Shares/Support.pm',

	'Shares/bollinger_band.pm'	=> '$(INST_LIBDIR)/Shares/bollinger_band.pm',
	'Shares/compare.pm'		=> '$(INST_LIBDIR)/Shares/compare.pm',
	'Shares/data.pm'		=> '$(INST_LIBDIR)/Shares/data.pm',
	'Shares/exponential_average.pm'	=> '$(INST_LIBDIR)/Shares/exponential_average.pm',
	'Shares/gradient.pm'		=> '$(INST_LIBDIR)/Shares/gradient.pm',
	'Shares/greater_equal.pm'	=> '$(INST_LIBDIR)/Shares/greater_equal.pm',
	'Shares/greater_than.pm'	=> '$(INST_LIBDIR)/Shares/greater_than.pm',
	'Shares/highest.pm'		=> '$(INST_LIBDIR)/Shares/highest.pm',
	'Shares/historical_highs.pm'	=> '$(INST_LIBDIR)/Shares/historical_highs.pm',
	'Shares/historical_lows.pm'	=> '$(INST_LIBDIR)/Shares/historical_lows.pm',
	'Shares/is_falling.pm'		=> '$(INST_LIBDIR)/Shares/is_falling.pm',
	'Shares/is_rising.pm'		=> '$(INST_LIBDIR)/Shares/is_rising.pm',
	'Shares/less_equal.pm'		=> '$(INST_LIBDIR)/Shares/less_equal.pm',
	'Shares/less_than.pm'		=> '$(INST_LIBDIR)/Shares/less_than.pm',
	'Shares/lowest.pm'		=> '$(INST_LIBDIR)/Shares/lowest.pm',
	'Shares/mark.pm'		=> '$(INST_LIBDIR)/Shares/mark.pm',
	'Shares/maximum.pm'		=> '$(INST_LIBDIR)/Shares/maximum.pm',
	'Shares/minimum.pm'		=> '$(INST_LIBDIR)/Shares/minimum.pm',
	'Shares/momentum.pm'		=> '$(INST_LIBDIR)/Shares/momentum.pm',
	'Shares/moving_average.pm'	=> '$(INST_LIBDIR)/Shares/moving_average.pm',
	'Shares/multiline_mean.pm'	=> '$(INST_LIBDIR)/Shares/multiline_mean.pm',
	'Shares/on_balance_volume.pm'	=> '$(INST_LIBDIR)/Shares/on_balance_volume.pm',
	'Shares/oversold.pm'		=> '$(INST_LIBDIR)/Shares/oversold.pm',
	'Shares/percent_band.pm'	=> '$(INST_LIBDIR)/Shares/percent_band.pm',
	'Shares/rate_of_change.pm'	=> '$(INST_LIBDIR)/Shares/rate_of_change.pm',
	'Shares/sample_mean.pm'		=> '$(INST_LIBDIR)/Shares/sample_mean.pm',
	'Shares/standard_deviation.pm'	=> '$(INST_LIBDIR)/Shares/standard_deviation.pm',
	'Shares/undersold.pm'		=> '$(INST_LIBDIR)/Shares/undersold.pm',
	'Shares/value.pm'		=> '$(INST_LIBDIR)/Shares/value.pm',
	'Shares/weighted_average.pm'	=> '$(INST_LIBDIR)/Shares/weighted_average.pm',
    },
);
