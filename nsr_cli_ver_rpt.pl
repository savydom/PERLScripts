#!/bin/perl
# $Id: nsr_cli_ver_rpt.pl,v 1.4 2017/03/03 14:53:33 gbrandt Exp $
#
#
#
#
##########################################################################
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#
#          File:  nsr_cli_ver_rpt.pl.pl
#        Author:  
#          Date:  Friday, August 28, 2015 
#
#                 Generated by bshdr
#                 Developed by Gene Brandt
#                 504 452-3250
#
##########################################################################
#
#	Description:
#	Generate NetWorker Clients Version Report
#
#       $Log: nsr_cli_ver_rpt.pl,v $
#       Revision 1.4  2017/03/03 14:53:33  gbrandt
#       Added a csv output file version.
#
#       Revision 1.3  2017/03/03 14:30:31  gbrandt
#       Fixed hardcopy output lines perpage.
#
#       Revision 1.2  2017/03/03 14:06:44  gbrandt
#       Added script introduction and output to a file. The page header includes
#       the script file name and version.
#
#       Revision 1.1  2017/03/03 13:32:18  gbrandt
#       Initial revision
#
#
##########################################################################
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                            Environmentals                              #
##########################################################################
#
#

$DEBUG=0;
$QRY_FILE_NAME="/tmp/nsr_cli_ver_rpt_qry.$$";
$RPTDATE=`date '+%m/%d/%Y'`;
$RPTTIME=`date '+%H:%M:%S'`;
$MaxLines=60;
$RPT_FILE_NAME="/tmp/nsr_cli_ver_rpt_";


#
#
##########################################################################
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                               Processing                               #
##########################################################################
#
#

introduction("Networker Client Version Report");

#
#     Get NSR server from command line.
#

if ( $#ARGV != 0 )
   {
   printf "\n\n     Usage $0 NetWorker Server Name\n\n";
   exit;
   }
chomp($RPTDATE);
chomp($RPTTIME);                                                                                               
$NSR_Server=$ARGV[0];
$RPT_FILE_NAME.= $NSR_Server;
$CSV_FILE_NAME = $RPT_FILE_NAME . ".csv";
#
#     Open report file.
#

open(RPT, ">$RPT_FILE_NAME") || die "     Error: Unable to open $RPT_FILE_NAME $!!\n\n";
open(CSV, ">$CSV_FILE_NAME") || do {
printf "     Error: Unable to open $CSV_FILE_NAME$!!\n\n";
};
#
#     Build NetWorker Query
#
open(QRY, ">$QRY_FILE_NAME") || die "Unable to write $QRY_FILE_NAME $!!\n\n";
printf QRY ". type: nsr client;scheduled backup: Enabled\n";
printf QRY "show name;client OS type;NetWorker version\n";
printf QRY "print\n";
close(QRY);

chmod(0666, $QRY_FILE_NAME);
$QRY_COMMAND="nsradmin -s $NSR_Server -i $QRY_FILE_NAME|";
#
#     Run run the querry
#
open(RESULT,$QRY_COMMAND) || die "Unable to run $QRY_COMMAND $!!\n\n";
while(<RESULT>)
   {
   if ($DEBUG)
      {
      print ;
      }
   chomp();
   tr /;//d;
   tr /"//d;
   if (/name/)
      {
      @words=split(/\s+/);
      $Client_Name=$words[-1];
      }
   if (/client OS/)
      {
      @words=split(/:/);
       $StrLen=length($words[-1]);
      if($DEBUG)
        {
        printf "     Debug Line: %3d Value - $words[-1]  Length- $StrLen\n",__LINE__;
        }
      $ClientOS{$Client_Name}=$words[-1];
      $ClientOS{$Client_Name}=~ s/^\s+//;    #   remove leading spaces.
      if ( $ClientOS{$Client_Name} =~ "Windows" )
         {
         $ClientOS{$Client_Name} = "Windows";
         }
      if ($StrLen <= 1)
         {
         $ClientOS{$Client_Name}="Unknown";
         }
      }
   if(/NetWorker/)
      {
      @words=split(/:/);
      $StrLen=length($words[-1]);
      $Clientver{$Client_Name}=$words[-1];
      $Clientver{$Client_Name}=~ s/^\s+//;    #   remove leading spaces.
      if ($StrLen <= 1)
         {
         $Clientver{$Client_Name}="Unknown";
         }
      }
   }

#
#     Display results
#
$PageCount=0;
page_hdr();
$ClinetCount=0;
foreach $ClientName (sort keys %ClientOS)
   {
   if ($LineCount > $MaxLines)
      {
      if ($PageCount > 0)
         {
         printf RPT "\n\n";
         }
      page_hdr();
      }
   $ClientCount++;
   $LineCount++;
   $Warn = "";
   if ( $ClientName =~ $NSR_Server )
      {
      $Warn = "*******";
      }
   if ( $Clientver{$ClientName} =~ "8.1" )
      {
      $Warn = "++";
      }
   if ( $Clientver{$ClientName} =~ "^7." )
      {
      $Warn = "+++++";
      }
   printf RPT "   %3d %-28s  %-8s       %s %s\n",$ClientCount, $ClientName, $ClientOS{$ClientName}, $Clientver{$ClientName},$Warn;
   printf CSV "%d,%s,%s,%s,%s\n",$ClientCount, $ClientName, $ClientOS{$ClientName}, $Clientver{$ClientName},$Warn;
   }

#
##########################################################################
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                               House Keeping                            #
##########################################################################
#
#

close(RPT);
close(CSV);
unlink($QRY_FILE_NAME);
printf "\n      Your report is in $RPT_FILE_NAME\n      A csv version: $CSV_FILE_NAME\n\n";


#
##########################################################################
###############  S P A W A R   S H A R E D   S E R V I C E S  ############
##########################################################################
#                              Sub Routines                              #
##########################################################################
#
#

sub introduction {
    $ProgName      = shift;
    $NameLength    = length($ProgName);
    $NameHeader    = "|   +++  ";
    $NameTrailer   = "  +++   |";
    $NameOffset    = 10;
    $DashCount     = 16 + $NameLength;
    $VersionLength = 18;                  #      Length of Version information.
    $VersionOffset = ( $DashCount - $VersionLength ) / 2;

    if ($DEBUG) {
        printf "     Debug Line: %3d Program name:%s\n     Length:%d",
          __LINE__, $ProgName, $NameLength;
        printf "     VersionOffset: %d\n", $VersionOffset;
    }
    open( SOURCE, $0 ) || die "Unable to open $0 for reading\n\n";
    while (<SOURCE>) {
        if (/Id:/) {
            @Column  = split(/\s+/);
            $ProgVer = $Column[3];
            printf "\n\n";
            print ' ' x $NameOffset;
            printf "+";
            print '-' x $DashCount;
            print "+\n";

            print ' ' x $NameOffset;
            printf "%s",   $NameHeader;
            printf "%s",   $ProgName;
            printf "%s\n", $NameTrailer;

            print ' ' x $NameOffset;
            print "|";
            print ' ' x $VersionOffset;
            printf "-- Version %4s --", $ProgVer;
            print " "
              if ( $NameLength % 2 == 1 )
              ;   #      Print an extra " " if the name length is an odd number.
            print ' ' x $VersionOffset;
            print "|\n";

            print ' ' x $NameOffset;
            printf "+";
            print '-' x $DashCount;
            print "+\n";
            last;
        }
    }
    close(SOURCE);
}

sub page_hdr
   {
   $PageCount++;
   printf RPT "   NetWorker Client Version Report     %10s\n",$NSR_Server;
   printf RPT "   ========= ====== ======= ======     ===========\n";
   printf RPT "   %s    Version: %4s\n",$0,$ProgVer;
   printf RPT "   Report Date: $RPTDATE                                             Page: %2d\n",$PageCount;
   printf RPT "   Report Time: $RPTTIME\n\n";
   printf RPT "   CLI %-26s  %-8s        %s\n","Client Name","Client OS","NetWorker Version";
   printf RPT "   CNT %-26s  %-8s        %s\n","===========","=========","=================";
   $LineCount=8; 
   if ($PageCount == 1 )
     {
     printf CSV "\"NetWorker Client Version Report\",\"$ProgVer\",\"$RPTDATE\",\"$RPTTIME\"\n";
     printf CSV "\"Line Number\",\"Client Name\",\"Client OS\",\"NetWorker Version\"\n";
     }
   }
