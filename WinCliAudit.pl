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
#          File:  WinCliAudit.pl
#        Author:  gbrandt
#          Date:  Wednesday, July 17, 2013
#
##########################################################################
#
#	Description:
#	Windows Client Audit
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

$WCAQRYNAME = "/tmp/wcaqry$$";
$MAXLINE    = 60;
$LineCount  = $MAXLINE + 1;
$PageCount  = 0;
$RPTDATE    = `date '+%m/%d/%Y'`;
$RPTTIME    = `date '+%H:%M:%S'`;

#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                               Processing                               #
##########################################################################
#
#

#
#       Evaluate command line.
#

if ( $#ARGV < 0 )
{
    printf "\n\n     Usage: $0 server_name \n\n";
    printf
"     Displays a report of a Windows client's Networker versioa.n If an additional file\n";
    printf
"     is entered, a csv file is generated. The \".csv\" will be appended to the filename entered.\n\n";
    exit(1);
}
if ( $#ARGV == 1 )
{
    $CSVNAME = $ARGV[1];
    $CSVNAME .= ".csv";
    printf "Creating file: %s\n", $CSVNAME;
    open( CSV, ">$CSVNAME" ) || die "Can't open $CSVNAME $!.\n\n:";
}
$Server = $ARGV[0];

chomp($RPTDATE);
chomp($RPTTIME);
#
#     Compose query.
#

open( QRY, ">$WCAQRYNAME" ) || die "Can't open $WCAQRYNAME $!\n\n";
printf QRY "option regexp\n";
printf QRY ". type:nsr client;client OS type: Win.*;scheduled backup:enabled\n";
printf QRY "show name;client OS type;NetWorker version\n";
printf QRY "print\n";
close(QRY);

$QryCmd = "nsradmin  -s $Server -i $WCAQRYNAME|";
open( QRY, $QryCmd ) || die "Can't run $QryCmd $!\n";
$ClientCount = 0;
while (<QRY>)
{
    chomp();
    tr /;//d;
#
#     Skip the opening lines that describe the query.
#
    if (   /Display/
        || /Dynamic/
        || /Hidden/
        || /Raw/
        || /Resource/
        || /Regexp/
        || /Current/ )
    {
        next;
    }
    if (/name/)
    {
        @NAME = split(/:/);
        $ClientName[$ClientCount] = $NAME[1];
        next;
    }
    if (/client/)
    {
        @OS = split(/:/);
        if ( length( $OS[1] ) > 2 )
        {
            $ClientOS[$ClientCount] = $OS[1];
        }
        else
        {
            $ClientOS[$ClientCount] = "Unknown";
        }
        next;
    }
    if (/NetWorker/)
    {
        @VERSION = split(/:/);
        if ( length( $VERSION[1] ) > 2 )
        {
            $ClientVersion[$ClientCount] = $VERSION[1];
        }
        else
        {
            $ClientVersion[$ClientCount] = " Unknown";
        }

#      printf "%23s  ",$ClientName[$ClientCount];
#      printf "%35s  ",$ClientOS[$ClientCount];
#      printf "%s\n",$ClientVersion[$ClientCount];
        $ClientCount++;

#      $LineCount++;
        next;
    }
}
#
#     Sort data for easier reading.
#

foreach $SortedClient ( sort (@ClientName) )
{
    $Sortcount = 0;
    foreach $Client (@ClientName)
    {
        if ( $Client eq $SortedClient )
        {
            if ( $LineCount > $MAXLINE )
            {
                if ( $#ARGV != 1 )
                {
                    page_header();
                }
            }
            if ( $#ARGV != 1 )
            {
                printf "%23s  %35s  %s\n", $SortedClient,
                  $ClientOS[$Sortcount], $ClientVersion[$Sortcount];
            }
            else
            {
                printf CSV "%s,%s,%s\n", $SortedClient, $ClientOS[$Sortcount],
                  $ClientVersion[$Sortcount];
            }
            $LineCount++;
            $Sortcount++;
            last;
        }
        $Sortcount++;
    }
}
close(QRY);

if ( $#ARGV == 1 )
{
    close(CSV);
}

#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                               Sub Routines                             #
##########################################################################
#
#

sub page_header
{
    $PageCount++;
    if ( $PageCount == 1 )
    {
        printf
          "     NetWorker Windows Clinet Audit  %s (WinCliAudit.pl)\n",
          $Server;
    }
    else
    {
        printf
          "     NetWorker Windows Clinet Audit %s (WinCliAudit.pl)\n",
          $Server;
    }
    printf
"     Report Date: %s                                             Page %2d\n",
      $RPTDATE, $PageCount;
    printf "     Report Time: %s\n\n", $RPTTIME;
    printf "%23s  %35s  %s\n", "Client Name", "Client OS", " Networker Version";
    printf "%23s  %35s  %s\n\n", "===========", "=========",
      " =================";
    $LineCount = 8;
    return (1);
}

#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                               House Keeping                            #
##########################################################################
#
#

unlink($WCAQRYNAME);
