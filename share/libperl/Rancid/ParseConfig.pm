#!/usr/local/bin/perl5.6.1 -w

# common code for Rancid programs written in Perl
# that want to parse a Rancid config file like cloginrc


package Rancid::ParseConfig;

use Regexp::Shellish qw(shellish_glob);

use strict;
use warnings;
use Carp qw(cluck croak carp confess);
use Exporter;

@Rancid::ParseConfig::ISA = qw(Exporter);
@Rancid::ParseConfig::EXPORT = qw(load_rancid_config find_rancid_config);

# Configurable things
my $cloginrchelper= "/usr/local/rancid/bin/cloginrc2pl.exp";  # hopefully in the PATH

# local state
my %_cloginrc_data;


BEGIN {
	1;
}


my $config_file_depth;

# cloginrc format:
#                 add <directive> <hostname glob> {<value>} [{<value>} ...]
#                   or
#                 include {<file>}

# _cloginrc_data storage:
#
# $_cloginrc_data{$directive}[0]= [hostglob0, value0, value1 ...]
# $_cloginrc_data{$directive}[1]= [hostglob1, value0, value1 ...]
# ...
#

sub load_rancid_config()
{
	my $file; 
        exists($ENV{'RANCID_CLOGINRC'}) ? $file = $ENV{'RANCID_CLOGINRC'} : $file = "$ENV{'HOME'}/.cloginrc";
	croak "$0: cloginrc file $file does not exist\n" unless -e $file;
	croak "$0: cloginrc file $file is not a regular file\n" unless -f $file;
	croak "$0: cloginrc file $file is empty\n" unless -s $file;

	my @filedata= stat($file);
	croak "$0: cloginrc file $file is world readable\n" if ($filedata[2] & 007);

#    load $file into %_cloginrc_data
	open HELPER, "$cloginrchelper $file|" ||
		croak "$0: error invoking pipe \"$cloginrchelper $file\": $!\n";
	while(<HELPER>)
	{
		eval; croak $@ if $@;
	}
	close HELPER ||
		croak "$0: error closing pipe \"$cloginrchelper $file\": $!\n";
}

# return a (possibly null)  array of values for a matched key in configdata
# if optional 3rd parameter supplied, return scalar at that position in
# array if it exists, undef otherwise.
sub find_rancid_config($$;$) # key, hostglob, [index]
{
	my $directive= shift;
	my $hostglob= shift;
	my $argindex= shift;
	my @matches;
	my @retvalues= ();

	if ( exists($Rancid::ParseConfig::_cloginrc_data{$directive}) )
	{
		my $topref=  $Rancid::ParseConfig::_cloginrc_data{$directive};
		foreach my $arrayref (@$topref)
		{
			@matches= shellish_glob(${$arrayref}[0], ($hostglob));
			if (@matches > 0)
			{
				@retvalues= @{$arrayref};
				shift @retvalues;
				last;
			}
		}
	}

	if (!defined($argindex))
	{
		return @retvalues;
	} elsif ($argindex =~ /^\d+$/ and $argindex < @retvalues) {
		return $retvalues[$argindex];
	} else {
		return undef;
	}
}

1;

__END__

=head1 NAME

Rancid::Parseconfig - Parse a RANCID cloginrc file

=head1 SYNOPSIS

  use Rancid::Parseconfig;
  load_rancid_config();       # load $HOME/.cloginrc
  load_rancid_config($file);  # load information from $file
  [...]
  @results= find_rancid_config("password", $hostglob); # all results
  $pw= find_rancid_config("password", $hostglob, 0);   # just the first result

=head1 DESCRIPTION

B<Rancid::ParseConfig> is used by Perl programs that want to retrieve
information from a RANCID login information file (I<cloginrc>), which is
normally used by scripts written in the B<expect> language.

=head1 OPERATION

The B<load_rancid_config()> function invokes an Expect script,
B<cloginrc2pl.exp>,
to parse the I<cloginrc> file.  Thus, all Expect quoting rules
apply to the I<cloginrc> file, even though the text strings are
being fed to a Perl program.

=head1 REQUIREMENTS

B<Rancid::ParseConfig> requires the B<Regexp::Shellish> module, available
from CPAN.

=head1 AUTHOR
Written by Ed Ravin <eravin@panix.com>, and made available courtesy of
PANIX Public Access Networks, http://panix.com.  License is GPL.
