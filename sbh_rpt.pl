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
#          File:  sbh_rpt.pl
#        Author:  gbrandt
#          Date:  Tuesday, July 16, 2013
#
##########################################################################
#
#	Description:
#	Server backup history report.
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

$Datadir       = "/backup/nsr/Summaries";
$Datadir2012   = "$Datadir/2012";
$MAXLINES      = 60;
$PageLineCount = $MAXLINES + 1;
$PageCount     = 0;
$RPTDATE       = `date '+%m/%d/%y'`;
$RPTTIME       = `date '+%H:%M:%S'`;
chomp($RPTDATE);
chomp($RPTTIME);

#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                               Processing                               #
##########################################################################
#
#

#
#	Evaluate command line.
#
if ( $#ARGV < 0 )
{
    printf "\n\n     Usage: $0 client_name \n\n";
    printf "     Displays a list of dates of successfule backups for the client entered on the command line.\n\n";
    exit(1);
}

$ClientName = $ARGV[0];


process_files($Datadir2012);
process_files($Datadir);

#
#    End of report summary.
#

if ( $PageLineCount >= $MAXLINES )
{
    page_hdr();
}
# printf "End of Report.        %d instances found. Failures: %d\n", $BackupInstance, $FailedInstance; 
printf "End of Report.        %d instances found.\n", $BackupInstance; 

#
#      Sub routines
#

sub page_hdr()
{
$PageCount++;
    if ($PageCount == 1)
       {
       printf
       "Successfull backup dates for %s                                  Page %2d\n",
       $ClientName, $PageCount;
       }
    else
       {
       printf
       "Successfull backup dates for %s                                  Page %2d\n",
      $ClientName, $PageCount;
       }
    printf "Report Date: %s %s\n\n", $RPTDATE, $RPTTIME;
    $PageLineCount = 3;
    return (1);
}

sub process_files()
{
    $WorkDir = shift;
    chdir($WorkDir);
    opendir $DH, $WorkDir;
    @Files = readdir $DH;
    closedir $DH;
    foreach $SummaryFile ( sort(@Files) )
    {
#
#    open the file and look.
#
        open( SUM, "$WorkDir/$SummaryFile" )
          || printf "Can't open $WorkDir/$SummaryFile $!\n\n";
        while (<SUM>)
        {
            if ( /$ClientName/ && /Succeeded/ )
            {
                $BackupInstance++;
                $SumYear  = substr $SummaryFile, 0,  4;
                $SumMonth = substr $SummaryFile, 4,  3;
                $SumDay   = substr $SummaryFile, 7,  2;
                $SumHour  = substr $SummaryFile, 10, 2;
                $SumMin   = substr $SummaryFile, 12, 2;
                if ( $PageLineCount >= $MAXLINES )
                {
                    page_hdr();
                }

                printf "%s %s, %s  %2d:%02d\n", $SumMonth, $SumDay, $SumYear,
                  $SumHour, $SumMin;
                $PageLineCount++;
            }
            if ( /$ClientName/ && /Fail/ )
               {
               $FailedInstances++;
               }
        }
        close(SUM);
    }

}


#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                               House Keeping                            #
##########################################################################
#
#
