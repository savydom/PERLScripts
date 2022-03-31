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
#          File:  ntwkr_client_audit.pl
#        Author:  gbrandt
#          Date:  Friday, April  5, 2013 
#
##########################################################################
#
#	Description:
#	Audit input list of clients against NetWorker clients.
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

# $AUDIT_INPUT="SSCSDhosts-04-04-2013.csv";
$HOSTNAME=`hostname`;
$RPTDATE=`date '+%m/%d/%y'`;
$RPTTIME=`date '+%H:%M:%S'`;
$MAXLINES = 60;
$LineCount = $MAXLINES + 1;
$PageLineCount=8;

#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                               Processing                               #
##########################################################################
#
#


chomp($HOSTNAME);
chomp($RPTDATE);
chomp($RPTTIME);


$GOOD_CLIENT_COUNT=0;
$INVALID_CLIENT_NAME_COUNT=0;
$NOMATCH_CLIENT_NAME_COUNT=0;

if ($#ARGV < 1)
   {
   printf "Usage: %s server file.csv\n\n",$0;
   exit;
   }
$Server=$ARGV[0];
$AUDIT_INPUT=$ARGV[1];

# open audit file and place client list in an array.

open (AUD_INP, $AUDIT_INPUT) || die "Can't open $AUDIT_INPUT $! \n";
@ClientInfo=<AUD_INP>;
close(AUD_INP);

#
#   Loop through array.
#

$ClientCount = 0;

$TotalPages = $#ClientInfo / ($MAXLINES - 7);
# printf "Debug: %f Total Pages\n", $TotalPages;

#
#    Report headder.
#
if ( $TotalPages > int($#ClientInfo / ($MAXLINES - 7)))
   {
   $TotalPages++;
   }
$PageCount = 1;
while ($ClientCount <= $#ClientInfo)
   {
if ( $LineCount > $MAXLINES )
   {
   if ($PageCount > 1)
     {
     printf "";
     $PageLineCount=8;
     }

   printf "Backup audit for NetWorker server %9s\n", $Server;
   printf "Processing file: %s\n", $AUDIT_INPUT;
   printf "                                                               ";
   printf "Date: %s\n", $RPTDATE;
   printf "                                                               ";
   printf "Time: %s\n", $RPTTIME;
   printf "                                                               ";
   printf "Page: %2d of %2d\n", $PageCount, $TotalPages;
   printf "%23s           %s  %s\n\n", "Client Name", "Group", "Status";
   $LineCount = 8;
   $PageCount++;
   }
#   $ClientInfo[$ClientCount]=~tr/,/ /;   # Some servers have spaces in their names!
   $ClientInfo[$ClientCount]=~tr/"//d;
#   @field = split(/\s+/, $ClientInfo[$ClientCount++]);
   @field = split(/,/, $ClientInfo[$ClientCount++]);   # Some servers have spaces in their names!
   $fqdn= $field[0];
#   printf "Debug: %s\n", $fqdn;
   @ShortName = split(/\./, $fqdn);       # Chop off short name.
   chomp($ShortName[0]);
   printf "%23s\t", $ShortName[0];

#
#    Check for group name.
#
$SYS_CMD="mminfo  -s $Server -t 'last week' -q \"client=$ShortName[0]\" -r group 2>&1|";
open(CMD,$SYS_CMD) || die "Can't run $SYS_CMD $!\n";
while(<CMD>)
   {
   if (/mminfo/)
      {
      printf "%15s  ", "No Group";
      last;
      }
   chomp();
   printf "%15s  ", $_ ;
   last;
   }
close(CMD);

#
#    Check Networker for client information.
#
#    $SYS_CMD="mminfo -t 'yesterday' -c $ShortName[0] 2>&1|";
   $SYS_CMD="mminfo -t 'last week' -q \"client=$ShortName[0]\" 2>&1|";
   open(CMD, $SYS_CMD) || die "Can't run $SYS_CMD $!\n";
   while (<CMD>)
      {
      if ( /no matches found/)
         {
         printf "Not found in the last week!\n";
         $NOMATCH_CLIENT_NAME_COUNT++;
         $LineCount++;
         last;
         }
      if (/volume/)
         {
         print "Ok\n";
         $LineCount++;
         last;
         }
      }
   close(CMD);
   }

printf "\n\n\n\n";
$LineCount+=4;
if ( $LineCount > $MAXLINES )
   {
   if ($PageCount > 1)
     {
     printf "";
     }

   printf "Audit for Networker on %s\nDate: %s\nTime: %s\n", $HOSTNAME, $RPTDATE, $RPTTIME;
   printf "Page %2d of %2d\n", $PageCount, $TotalPages;
   printf "%23s\t%s\n\n", "Client Name", "Status";
   $LineCount = 8;
   $PageCount++;
   }

printf "********************  Summary  ********************\n";

printf "        Client Audit Count: %3d\n", $ClientCount;
# printf " Invalid Client Name Count: %3d\n", $INVALID_CLIENT_NAME_COUNT;
printf "No Client Name Match Count: %3d\n", $NOMATCH_CLIENT_NAME_COUNT;

#
#
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                               House Keeping                            #
##########################################################################
#
#
