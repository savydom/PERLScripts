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
#          File:  nsr_group_analisys.pl
#        Author:  gbrandt
#          Date:  Friday, May 24, 2013 
#
##########################################################################
#
#	Description:
#	Analyse - display a group's start and stop time.
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

$SummariesDirectory="/nsr/Summaries";
@month   = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
@Month   = qw( January February March April May Jun July August September October November December );

#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                               Processing                               #
##########################################################################
#
#

#
#     Check the machine we are running.
#

$Host = `hostname`;

if ( ($Host  !~ "sscprodeng") && ($Host  !~ "sdprodeng") )
  {
  printf "Wrong host!\n\n";
  exit 2;
  }

#
#     Read the command line arguments.
#

if ( $#ARGV != 1 )
   {
   printf "Usage: $0 group_name month\n\n";
   exit 1;
   }
$Group = $ARGV[0];
$Mn = $ARGV[1] - 1;

#
#     Go to the group summaries directory.
#

chdir($SummariesDirectory);
opendir($Directory, ".");                                                                                            
@Filelist= readdir $Directory;                                                                                           
closedir($Directory);                                                                                                

#
#     For each file for that group. Print the groups start and end times.
#

$FileCount = 0;
foreach $File (@Filelist)
   {
   if ($File =~ /$Group/ && $File =~ /$month[$Mn]/) 
      {
      @Tuple = split(/_/, $File);
      if ($Tuple[$#Tuple] eq $Group)
         {
         $MonthList[$FileCount++] = $File;
         }

      }
   }

if ($#MonthList >= 0)
   {
printf "Displaying times for group: %s in %s\n", $Group, $Month[$Mn];
printf "|------   Start  ------|      |--------  End  -------|     |--- Elapsed ---|\n";
   }
else
   {
   printf "No records found for group %s in %s\n\n", $Group, $Month[$Mn];
   }

foreach $Day (sort (@MonthList))
   {
   display_info();
   }
#
#     Print the number of times the group has run this year.
#







sub display_info
{

open(FilePtr, $Day) || die "Can't open file $Day $!\n";
while(<FilePtr>)
   {
   if (/Start time/)
      {
      chomp();
      @entry = split(/\s+/);
      printf "%s %s %2d %s %4d      ", $entry[2], $entry[3], $entry[4], $entry[5], $entry[6];
#     $RealDate2 = "Sat May 18 21:34:01 2013";
      $RealDate1 =sprintf "%s %s %2d %s %4d", $entry[2], $entry[3], $entry[4], $entry[5], $entry[6];
      }
   if (/End time/)
      {
      @entry = split(/\s+/);
      printf "%s %s %2d %s %4d     ", $entry[2], $entry[3], $entry[4], $entry[5], $entry[6];
#     $RealDate1 = "Sat May 18 01:20:00 2013";
      $RealDate2 =sprintf "%s %s %2d %s %4d", $entry[2], $entry[3], $entry[4], $entry[5], $entry[6];
      datediff();
      }
   }
close(FilePtr);
}


#
#      Sub Routines
#

##########################################################################
#
#          File:  elapsedtime.pl
#        Author:  gbrandt
#          Date:  Tuesday, May 28, 2013
#
##########################################################################
#
#	Description:
#	Display elapsed time between 2 dates and times.
#       No accounting for leap years.
#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#


sub datediff
{

$secmin  = 60;
$sechour = $secmin * 60;
$secday  = $sechour * 24;
$secweek = $secday * 7;
$secyear = $secweek * 52;
@MONTHS = ( Dummy, Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec );
@dayspmonth = ( 00, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );

# printf "Seconds per minute: %8d\n", $secmin;
# printf "Seconds per hour:   %8d\n", $sechour;
# printf "Seconds per day:    %8d\n", $secday;
# printf "Seconds per week:   %8d\n", $secweek;
# printf "Seconds per year:   %8d\n", $secyear;

#
#     Start time 24 hour format.
#
# Sat May 18 01:20:00 2013      Sat May 18 21:34:01 2013


#
#     Converting Real Date.
#
( $Rdow1, $Rmonth1, $Rday1, $Rtime1, $Ryear1 ) = split( /\s+/, $RealDate1 );
( $Rdow2, $Rmonth2, $Rday2, $Rtime2, $Ryear2 ) = split( /\s+/, $RealDate2 );

$MnthNum = 0;
foreach $Mnth (@MONTHS)
{
    $MnthNum++;
    if ( $Rmonth1 eq $Mnth )
    {
        $Rmonth1 = $MnthNum;
        last;
    }
}

$MnthNum = 0;
foreach $Mnth (@MONTHS)
{
    $MnthNum++;
    if ( $Rmonth2 eq $Mnth )
    {
        $Rmonth2 = $MnthNum;
        last;
    }
}

$Date1 = sprintf "%d/%d/%4d %s", $Rmonth1, $Rday1, $Ryear1, $Rtime1;
$Date2 = sprintf "%d/%d/%4d %s", $Rmonth2, $Rday2, $Ryear2, $Rtime2;
# printf "Rmonth1: %d     Rmonth2: %d\n", $Rmonth1, $Rmonth2;

( $Daystring1, $Timestring1 ) = split( /\s+/, $Date1 );
# printf "%s   %s\n", $Daystring1, $Timestring1;
( $month1, $day1, $year1 ) = split( /\//, $Daystring1 );
( $hour1,  $min1, $sec1 )  = split( /:/,  $Timestring1 );

# printf "$month1,$day1,$year1   $hour1,$min1\n";
# printf "\n";

( $Daystring2, $Timestring2 ) = split( /\s+/, $Date2 );
# printf "%s   %s\n", $Daystring2, $Timestring2;
( $month2, $day2, $year2 ) = split( /\//, $Daystring2 );
( $hour2,  $min2, $sec2 )  = split( /:/,  $Timestring2 );

# printf "$month2,$day2,$year2   $hour2,$min2\n";

$YearDiff  = $year2 - $year1;
$MonthDiff = $month2 - $month1;

if ( $sec1 > $sec2 )
{
    $min2--;
    $sec2 += 60;
}
$SecDiff = $sec2 - $sec1;
# printf "Seconds difference is %d\n", $SecDiff;
if ( $min1 > $min2 )
{
    $hour2--;
    $min2 += 60;
}
$MinDiff = $min2 - $min1;
# printf "Minute difference is %d\n", $MinDiff;

if ( $hour1 > $hour2 )
{
    $day2--;
    $hour2 += 24;
}
$HourDiff = $hour2 - $hour1;
# printf "Hour difference is %s\n", $HourDiff;

if ( ($day1 > $day2) && ($month1 != $month2) )
{
    $month2--;
    $day2 += $dayspmonth[$month2-1];
    $DayDiff = $day2 - $day1;
}
else
   {
$DayDiff = $day2 - $day1;
}

# printf "Day difference is %d\n", $DayDiff;

printf "%s day(s) %2d:%02d:%02d\n", $DayDiff, $HourDiff,
  $MinDiff, $SecDiff;
#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                               House Keeping                            #
##########################################################################
#
#
}
#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                               House Keeping                            #
##########################################################################
#
#
