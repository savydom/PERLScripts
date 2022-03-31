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
#          File:  snapcheck.pl
#        Author:  gbrandt
#          Date:  Thursday, October 17, 2013 
#
##########################################################################
#
#	Description:
#	Check VADP group backup Summaries for snapshot cleanup.
#       Command line option allow you to select today files, yesterday's
#       files, or all the VADP group summary files.
#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#
#	Invocation:
#       Usage: snapcheck.pl [ all | yesterday | today ]
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

$MAXLINES   = 44;                  # Formatted for landscape output.
$LineCount  = $MAXLINES + 1;
$Page_count = 1;
$Data_dir   = "/nsr/Summaries/";
$RPTDATE    = `date '+%m/%d/%y'`;
$RPTTIME    = `date '+%H:%M:%S'`;

#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                               Processing                               #
##########################################################################
#
#
chomp($RPTDATE);
chomp($RPTTIME);

#
#     Get command line parameters or produce usage message.
#

if ( $#ARGV != 0 )
   {
   printf "\n     Usage: $0 [ all | yesterday | today ]\n\n";
   exit;
   }

$Constraint = $ARGV[0];

validate_system();

examine_constraint($Constraint);

#
#     Go to data directory.
#

chdir( $Data_dir );

#
#     Read the file list into an array.
#

opendir $GroupSumFH, $Data_dir || die "Couldn't open dir '$Data_dir: $!\n";

@GroupSummaries = readdir $GroupSumFH;

closedir $GroupSumFH;

foreach $File ( sort( @GroupSummaries ) )
   {
   if ( $File =~ "VADP" )              # We are only concerned with VADP group summaries.
      {
      if ( $Constraint =~ "all" )
         {
         process_summary( $File );
         }
      if ( ( $Constraint =~ "yesterday" ) && ( $File =~ $Cyear ) && ( $File =~ $Cmon ) && ( $File =~ $Cdow ) && ( $File =~ $Cday ) )
         {
         process_summary( $File );     # Process only yesterday's files.
         }
      if ( ( $Constraint =~ "today" ) && ( $File =~ $Cyear ) && ( $File =~ $Cmon ) && ( $File =~ $Cdow ) && ( $File =~ $Cday ) )
         {
         process_summary( $File );     # process only today's files.
         }
      }
   }

#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                              Sub  Routines                             #
##########################################################################
#
#

sub page_hdr
   {
   if ( $Page_count > 1 )
      {
      printf "";
      }
   printf "     Snapshot cleanup report (snapcheck.pl)                                                                       Page %2d\n",
      $Page_count++;
   printf "     Date: %s\n     Time: %s\n\n", $RPTDATE, $RPTTIME;
   printf "               %s         %s       %s        %s          %s\n", "Group","Start", "Start", "Client", "Issue";
   printf "               %s         %s       %s        %s          %s\n", " Name"," Date", " Time", " Name ", "Description";
   $LineCount=6;
   return;
   }

sub process_summary()
{
     $DataFile = shift;
     open( INFO, $DataFile ) ||  printf "       Unable to open $DataFile: $!.\n\n"; 
     while(<INFO>)
        {
        chomp();
        tr/*//d;                                  # Remove the peskie leading *
        tr/.'.//d;                                # Remove the strange .'. line endings
        if ( ( /snapshot/ ) && ( /Unable/ ) )     # Only line containing these words.
           {
              ( @words )=split( /:/ );            # Split up the line by :'s
              if ( $LineCount > $MAXLINES )
                 {
                 page_hdr();
                 }
              $SumYear    = substr $DataFile, 0,  4;     # Breakup the filename into it's components.
              $SumMonth   = substr $DataFile, 4,  3;
              $SumDay     = substr $DataFile, 7,  2;
              $SumHour    = substr $DataFile, 10, 2;
              $SumMin     = substr $DataFile, 12, 2;
              $SumWeekDay = substr $DataFile, 17, 3;
              $GroupName  = substr $DataFile, 21;

              $Issue = sprintf( "%s", $words[$#words] );     # Place the issues into a string for parsing.

              if ( $Issue =~ /snapshot manuall/ )            # Look for manual snapshot deletion request.
                 {
                 $Issue = "Delete the snapshot manually";
                 }

              if ( $Issue =~ /quiescing/ )                   # Look for quiescing problems.
                 {
                 $Issue = "An error occurred while quiescing the virtual machine";
                 }

              if ( $Issue =~ /unspecified filename/ )        # Look for unspecified  filenames.
                 {                                           # Could be a "maximum size" string.
                 $Issue = "An unspecified filename is larger than the maximum size supported by datastore";
                 }

              printf "\n     %18s  %3s %02d-%s-%4d %2d:%02d %17s:  %s.",
              $GroupName, $SumWeekDay,$SumDay, $SumMonth, $SumYear, $SumHour, $SumMin, $words[0],$Issue;
              $LineCount+=1;
           }
        }
     close( INFO );
     printf "\n";
     $LineCount+=1;
     return;
}

sub examine_constraint()
   {
   my $Constr = shift;

#
#      We don't need to do anything for "all".
#

   if ( $Constr =~ "yesterday" )
      {
      $date = scalar localtime ( time() -( 24*60*60 ) );
      ( $Cdow, $Cmon, $Cday, $Ctime, $Cyear ) = split( /\s+/, $date );     # Split the date returned into components.
      }

   if ( $Constr =~ "today" )
      {
      $date = scalar localtime ( time() );
      ( $Cdow, $Cmon, $Cday, $Ctime, $Cyear ) = split( /\s+/, $date );     # Split the date returned into components.
      }

   return;
   }

sub validate_system()
   {
   $Host=`/usr/bin/hostname`;
   if ((  $Host =~ "sscprodeng" ) || ( $Host =~ "sdprodeng" ) )
      {
      return;
      }
   printf "\n     $0 provides information from either sscprodeng or sdprodeng.\n\n";
   exit;
   }
#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                               House Keeping                            #
##########################################################################
#
#
