#!/usr/bin/perl
use warnings;
use strict;
use Test::More tests => 64;
use Finance::Shares::Model;
use Finance::Shares::Support qw(show add_show_objects line_dump line_compare);

my $filename = 't/030';

add_show_objects(
    'Finance::Shares::Line',
    'Finance::Shares::Code',
    'Finance::Shares::mark',
);

my $fsm = new Finance::Shares::Model( \@ARGV,
    verbose => 1,
    filename => $filename,

    lines => [
	# case_X have no line entries
	# mark only
	caseA0 => {},
	caseA1 => {},
	caseB0 => { out => [qw(one two)], },
	caseB1 => { out => [qw(one two)], },
	caseB2 => { out => [qw(one two)], },
	# no 'out' entries specified
	case00 => {},
	case01 => {},
	case02 => {},
	case03 => {},
	case04 => {},
	case05 => {},
	case06 => {},
	case07 => {},
	case08 => {},
	# 'out' entries given
	case10 => { out => [qw(one two)], },
	case11 => { out => [qw(one two)], },
	case12 => { out => [qw(one two)], },
	case13 => { out => [qw(one two)], },
	case14 => { out => [qw(one two)], },
	case15 => { out => [qw(one two)], },
	case16 => { out => [qw(one two)], },
	case17 => { out => [qw(one two)], },
	case18 => { out => [qw(one two)], },
    ],

    code => [
	# caseXYZ:
	# X=lines entry (_=no line,  0=no out, 1+=given),
	# Y=in mark()   (_=no_entry, d=default, g=given, m=missing)
	# Z=referenec (_=no_entry, d=default, g=given, m=missing)
	case_d => q(mark('case_', 110);),
	case_g => q(mark('case_/one', 111);),
	case0d => q(mark('caseA0', 112);),
	case0g => q(mark('caseA1/one', 113);),
	case1d => q(mark('caseB0', 114);),
	case1g => q(mark('caseB1/one', 115);),
	case1m => q(mark('caseB2/xxx', 116);),

	# case_.. all fail as reference needs line entry
	#case_dd => {
	#    before => q(my $fsl = $case_0;),		# default
	#    step   => q(mark('case_0', 107);),		# default
	#},
	
	# case0.. reference only works when mark is same line
	case0dd => {
	    before => q(my $fsl = $case00;),		# default
	    step   => q(mark('case00', 117);),		# default
	},
	case0dg => {
	    before => q(my $fsl = $case01/one;),	# one =0
	    step   => q(mark('case01', 118);),		# default
	},
	case0dm => {
	    before => q(my $fsl = $case02/xxx;),	# xxx =0
	    step   => q(mark('case02', 119);),		# default
	},
	case0gd => {
	    before => q(my $fsl = $case03;),		# default =0
	    step   => q(mark('case03/one', 120);),	# one
	},
	case0gg => {
	    before => q(my $fsl = $case04/one;),	# one
	    step   => q(mark('case04/one', 121);),	# one
	},
	case0gm => {
	    before => q(my $fsl = $case05/xxx;),	# xxx =0
	    step   => q(mark('case05/one', 122);),	# one
	},
	case0md => {
	    before => q(my $fsl = $case06;),		# default =0
	    step   => q(mark('case06/xxx', 123);),	# xxx
	},
	case0mg => {
	    before => q(my $fsl = $case07/one;),	# one =0
	    step   => q(mark('case07/xxx', 124);),	# xxx
	},
	case0mm => {
	    before => q(my $fsl = $case08/xxx;),	# xxx
	    step   => q(mark('case08/xxx', 125);),	# xxx
	},

	# case1..
	case1dd => {
	    before => q(my $fsl = $case10;),		# one
	    step   => q(mark('case10', 126);),		# one
	},
	case1dg => {
	    before => q(my $fsl = $case11/one;),	# one
	    step   => q(mark('case11', 127);),		# one
	},
	case1dm => {
	    before => q(my $fsl = $case12/xxx;),	# xxx =0
	    step   => q(mark('case12', 128);),		# one
	},
	case1gd => {
	    before => q(my $fsl = $case13;),		# one
	    step   => q(mark('case13/one', 129);),	# one
	},
	case1gg => {
	    before => q(my $fsl = $case14/one;),	# one
	    step   => q(mark('case14/one', 130);),	# one
	},
	case1gm => {
	    before => q(my $fsl = $case15/xxx;),	# xxx =0
	    step   => q(mark('case15/one', 131);),	# one
	},
	case1md => {
	    before => q(my $fsl = $case16;),		# one =0
	    step   => q(mark('case16/xxx', 132);),	# xxx
	},
	case1mg => {
	    before => q(my $fsl = $case17/one;),	# one =0
	    step   => q(mark('case17/xxx', 133);),	# xxx
	},
	case1mm => {
	    before => q(my $fsl = $case18/xxx;),	# xxx
	    step   => q(mark('case18/xxx', 134);),	# xxx
	},
    ],

    sample => {
	stock  => 'VOD.L',
	source => 't/vod.csv',
	code   => [
	    'case_d',
	    'case_g',
	    'case0d',
	    'case0g',
	    'case1d',
	    'case1g',
	    'case1m',

	    'case0dd',
	    'case0dg',
	    'case0dm',
	    'case0gd',
	    'case0gg',
	    'case0gm',
	    'case0md',
	    'case0mg',
	    'case0mm',
	
	    'case1dd',
	    'case1dg',
	    'case1dm',
	    'case1gd',
	    'case1gg',
	    'case1gm',
	    'case1md',
	    'case1mg',
	    'case1mm',
	],
    },
);


my ($nlines, $npages, @files) = $fsm->build();
#warn $fsm->show_model_lines;

is($npages, 1, 'Number of pages');
is($nlines, 38, 'Number of lines');

my $line;
my $dump = 0;

# marks only
$line = $fsm->{ptfsls}[0][0];
is($line->{data}[0], 110, 'case_d line');
is($line->{key}, "'case_'", 'case_d key');
$line = $fsm->{ptfsls}[0][1];
is($line->{data}[0], 111, 'case_g line');
is($line->{key}, "'case_/one'", 'case_g key');
$line = $fsm->{ptfsls}[0][2];
is($line->{data}[0], 112, 'case0d line');
is($line->{key}, "'caseA0'", 'case0d key');
$line = $fsm->{ptfsls}[0][3];
is($line->{data}[0], 113, 'case0g line');
is($line->{key}, "'caseA1/one'", 'case0g key');
$line = $fsm->{ptfsls}[0][4];
is($line->{data}[0], 114, 'case1d line');
is($line->{key}, "'caseB0/one'", 'case1d key');
$line = $fsm->{ptfsls}[0][5];
is($line->{data}[0], 115, 'case1g line');
is($line->{key}, "'caseB1/one'", 'case1g key');
$line = $fsm->{ptfsls}[0][6];
is($line->{data}[0], 116, 'case1m line');
is($line->{key}, "'caseB2/xxx'", 'case1m key');

# case0 - no 'out' field in line entry
$line = $fsm->{ptfsls}[0][7];
is($line->{key}, "'case00'", 'case0dd key');
$line = $fsm->{ptfsls}[0][8];
is($line->{key}, "'case01/one'",     'case0dg key');
$line = $fsm->{ptfsls}[0][9];
is($line->{data}[0], 118,            'case0dg line');
is($line->{key}, "'case01'", 'case0dg key');
$line = $fsm->{ptfsls}[0][10];
is($line->{key}, "'case02/xxx'",     'case0dm key');
$line = $fsm->{ptfsls}[0][11];
is($line->{data}[0], 119,            'case0dm line');
is($line->{key}, "'case02'", 'case0dm key');
$line = $fsm->{ptfsls}[0][12];
is($line->{key}, "'case03'", 'case0gd key');
$line = $fsm->{ptfsls}[0][13];
is($line->{data}[0], 120,            'case0gd line');
is($line->{key}, "'case03/one'",     'case0gd key');
$line = $fsm->{ptfsls}[0][14];
is($line->{data}[0], 121,            'case0gg line');
is($line->{key}, "'case04/one'",     'case0gg key');
$line = $fsm->{ptfsls}[0][15];
is($line->{key}, "'case05/xxx'",     'case0gm key');
$line = $fsm->{ptfsls}[0][16];
is($line->{data}[0], 122,            'case0gm line');
is($line->{key}, "'case05/one'",     'case0gm key');
$line = $fsm->{ptfsls}[0][17];
is($line->{key}, "'case06'", 'case0md key');
$line = $fsm->{ptfsls}[0][18];
is($line->{data}[0], 123,            'case0md line');
is($line->{key}, "'case06/xxx'",     'case0md key');
$line = $fsm->{ptfsls}[0][19];
is($line->{key}, "'case07/one'",     'case0mg key');
$line = $fsm->{ptfsls}[0][20];
is($line->{data}[0], 124,            'case0mg line');
is($line->{key}, "'case07/xxx'",     'case0mg key');
$line = $fsm->{ptfsls}[0][21];
is($line->{data}[0], 125,            'case0mm line');
is($line->{key}, "'case08/xxx'",     'case0mm key');

## case 1 - line entry has 'out' field
$line = $fsm->{ptfsls}[0][22];
is($line->{key}, "'case10/one'",     'case1dd key');
is($line->{data}[0], 126,            'case1dd line');
$line = $fsm->{ptfsls}[0][23];
is($line->{key}, "'case10/two'",     'case1dd key');
$line = $fsm->{ptfsls}[0][24];
is($line->{key}, "'case11/one'",     'case1dg key');
is($line->{data}[0], 127,            'case1dg line');
$line = $fsm->{ptfsls}[0][25];
is($line->{key}, "'case12/xxx'",     'case1dm key');
$line = $fsm->{ptfsls}[0][26];
is($line->{key}, "'case12/one'",     'case1dm key');
is($line->{data}[0], 128,            'case1dm line');
$line = $fsm->{ptfsls}[0][27];
is($line->{key}, "'case13/one'",     'case1gd key');
is($line->{data}[0], 129,            'case1gd line');
$line = $fsm->{ptfsls}[0][28];
is($line->{key}, "'case13/two'",     'case1gd key');
$line = $fsm->{ptfsls}[0][29];
is($line->{key}, "'case14/one'",     'case1gg key');
is($line->{data}[0], 130,            'case1gg line');
$line = $fsm->{ptfsls}[0][30];
is($line->{key}, "'case15/xxx'",     'case1gm key');
$line = $fsm->{ptfsls}[0][31];
is($line->{key}, "'case15/one'",     'case1gm key');
is($line->{data}[0], 131,            'case1gm line');
$line = $fsm->{ptfsls}[0][32];
is($line->{key}, "'case16/one'",     'case1md key');
$line = $fsm->{ptfsls}[0][33];
is($line->{key}, "'case16/two'",     'case1md key');
$line = $fsm->{ptfsls}[0][34];
is($line->{key}, "'case16/xxx'",     'case1md key');
is($line->{data}[0], 132,            'case1md line');

$line = $fsm->{ptfsls}[0][35];
is($line->{key}, "'case17/one'",     'case1mg key');
$line = $fsm->{ptfsls}[0][36];
is($line->{key}, "'case17/xxx'",     'case1mg key');
is($line->{data}[0], 133,            'case1mg line');

$line = $fsm->{ptfsls}[0][37];
is($line->{key}, "'case18/xxx'",     'case1mm key');
is($line->{data}[0], 134,            'case1mg line');
#warn"$line->{key} = ", $line->{data}[0] || '<undef>', "\n";

