#!/bin/perl
# $Id:$
#
#
#
#
##########################################################################
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#
#          File:  paraclient.pl
#        Author:  gbrandt
#          Date:  Friday, September 27, 2013
#
##########################################################################
#
#	Description:
#	Put client in a paralyzed group.
#
#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#
#	Invocation:
#
#
#
##########################################################################
#
#	Revisions:
#
#
#        $Log:$
#
#
##########################################################################
##########################################################################

#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                            Environmentals                              #
##########################################################################
#
#

$InputScript        = "/tmp/paraclient.inp_$$";
$ParalyzedGroupName = "paralyzed";
$PARA_Date          = `date '+%m/%d/%Y'`;
$PARA_Time          = `date '+%H:%M:%S'`;
$PARA_Who           = split( /\s+/, `who am i` );

#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                               Processing                               #
##########################################################################
#
#

if ( $#ARGV != 1 )
{
    printf "\n\n     Usage: %s servername clientname\n\n", $0;
    exit;
}

$ServerName = $ARGV[0];
$ClientName = $ARGV[1];
chomp($PARA_Date);
chomp($PARA_Time);

printf "     Paralyzing %s on %s\n\n", $ClientName, $ServerName;

#
#     Print a report on the clients current information.
#

open( CLQRY, ">$InputScript" ) || die "Can't open $InputScript $!\n\n";
printf CLQRY ". type:nsr client;name:%s\n", $ClientName;
printf CLQRY "show\n";
printf CLQRY "print\n";
close(CLQRY);

$CliRptName = sprintf "/tmp/%s-nsrclient.rpt", $ClientName;
open( CRN, ">$CliRptName" ) || die "     Can't open $CliRptName $! \n\n";
$CLQRYCMD = "nsradmin -s $ServerName -i $InputScript|";
open( SysCmd, $CLQRYCMD ) || die "     Can't run $CLQRYCMD $!\n\n";
while (<SysCmd>)
{
    print CRN $_;
}
close(SysCmd);
close(CRN);
unlink($InputScript);
printf "     %s report created.\n\n", $CliRptName;

#
#     Create a nsradmin update input script.
#
open( INP, ">$InputScript" ) || die "     Can't open $InputScript $!\n\n";
printf INP ". type:NSR client;name:%s\n",                      $ClientName;
printf INP "update comment:\"Paralyzed by %s on %s at %s\"\n", $PARA_Who[0],
  $PARA_Date, $PARA_Time;
printf INP "update group: %s\n", $ParalyzedGroupName;
close(INP);

$PARCmd = "nsradmin -s $ServerName -i $InputScript |";
open( PCMD, $PARCmd ) || die "     Can't run $PARCmd $! \n\n";
while (<PCMD>)
{
    print;
}
close(PCMD);
#
#     User feedback
#
printf "\n\n\n";
printf "     Please check that %s was paralyzed on %s.\n", $ClientName,
  $ServerName;
printf "     %s should be in the %s group.\n", $ClientName, $ParalyzedGroupName;
printf "     %s's Comment should reflect paralyzing information.\n\n",
  $ClientName;

#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                              Sub  Routines                             #
##########################################################################
#
#

#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                               House Keeping                            #
##########################################################################
#
#

unlink($InputScript);
