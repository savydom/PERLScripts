#!/bin/perl
# 	$Id: networker_recovers.pl,v 1.3 2017/12/22 15:48:33 gbrandt Exp $
#
#
#
#
###########################################################################
################  S P A W A R   S H A R E D   S E R V I C E S   ###########
###########################################################################
#
#          File:  networker_recovers.pl
#        Author:  Gene Brandt
#          Date:  Monday, December 18, 2017
#
#                 Generated by bshdr
#                 Developed by Gene Brandt
#                 504 452-3250
#
###########################################################################
#
#	Description:
#	Parce the daemon.raw output and report on recovers.
#
#	$Log: networker_recovers.pl,v $
#	Revision 1.3  2017/12/22 15:48:33  gbrandt
#	dded report date ands time.
#	Corrected a few spelling errors.
#	added gather routine to parce the daemon.raw files and create
#	one all imclusive daemon_all.out file.
#
#	Revision 1.2  2017/12/21 18:50:39  gbrandt
#	First working version.
#
#	Revision 1.1  2017/12/18 16:34:15  gbrandt
#	Initial revision
#
#
#
#
#
#
#         # ###        ##### ##                                       ##
#       /  /###  /  ######  /##                                        ##
#      /  /  ###/  /#   /  / ##                                        ##       #
#     /  ##   ##  /    /  /  ##                                        ##      ##
#    /  ###           /  /   /                                         ##      ##
#   ##   ##          ## ##  /   ###  /###     /###   ###  /###     ### ##    ########
#   ##   ##   ###    ## ## /     ###/ #### / / ###  / ###/ #### / ######### ########
#   ##   ##  /###  / ## ##/       ##   ###/ /   ###/   ##   ###/ ##   ####     ##
#   ##   ## /  ###/  ## ## ###    ##       ##    ##    ##    ##  ##    ##      ##
#   ##   ##/    ##   ## ##   ###  ##       ##    ##    ##    ##  ##    ##      ##
#    ##  ##     #    #  ##     ## ##       ##    ##    ##    ##  ##    ##      ##
#     ## #      /       /      ## ##       ##    ##    ##    ##  ##    ##      ##
#      ###     /    /##/     ###  ##       ##    /#    ##    ##  ##    /#      ##
#       ######/    /  ########    ###       ####/ ##   ###   ###  ####/        ##
#         ###     /     ####       ###       ###   ##   ###   ###  ###          ##
#                 #
#                  ##
#

#
###########################################################################
################  S P A W A R   S H A R E D   S E R V I C E S   ###########
###########################################################################
#                            Environmentals                               #
###########################################################################
#
#

$DEBUG    = 0;
$DataFile = "/nsr/logs/daemon_all.out";

#
#
###########################################################################
################  S P A W A R   S H A R E D   S E R V I C E S   ###########
###########################################################################
#                               Processing                                #
###########################################################################
#
#

#
#
###########################################################################
################  S P A W A R   S H A R E D   S E R V I C E S   ###########
###########################################################################
#                               Processing                                #
#                                  Notes                                  #
###########################################################################
#
#      To gather all the necessary data from the daemon.raw files run
#      nsr_render_data daemon.raw files appending output to daemon_all.out
#      sort unique daemon_all.out writing daemon_all.srt.

unshift( @INC, "/home/scriptid/scripts/local_lib_perl" );
require introduction;
use Sys::Hostname;
$Server = hostname;

#     For future use.
@Rmonth =
  qw( 0month January February March April May Jun July Aug September October November December );
$RecoverFailCount    = 0;
$RecoverSuccessCount = 0;
if ($DEBUG) {
    printf "     Debug Line:%3d Running on %s\n", __LINE__, $Server;
}

$RPTDATE = `date '+%m/%d/%y'`;
$RPTTIME = `date '+%H:%M:%S'`;
chomp($RPTDATE);
chomp($RPTTIME);
introduction("Networker Recovers");
gatherdata();
report_header();

#     Open data file for reading.

open( INP, $DataFile )
  || die "     Unable to open $DataFile $!! for reading.\n\n";

#     Read through data.
$Recordcount  = 0;
$RecoverCount = 0;
while (<INP>) {
    $Recordcount++;
    if (/failed to recover/) {
        $Notice = "Fail";
        $RecoverFailCount++;
    }

    if (/successfully recovered/) {
        $Notice = "    ";
        $RecoverSuccessCount++;
    }
    if ( (/failed to recover/) || (/successfully recovered/) ) {
        $RecoverCount++;
        chomp;
        ProcessRecord($_);
    }
}
close(INP);

#     Display information.

printf "      %4d records read.\n",    $Recordcount;
printf "      %4d recover records.\n", $RecoverCount;
printf "      %4d Successes.\n",       $RecoverSuccessCount;
printf "      %4d Failures.\n",        $RecoverFailCount;
#
#
###########################################################################
################  S P A W A R   S H A R E D   S E R V I C E S   ###########
###########################################################################
#                               Sub Routines                              #
###########################################################################
#
#

sub gatherdata {
    #
    #	Description:
    #	Build one daemon.out file from all available daemon.raw files.
    #
###########################################################################
################  S P A W A R   S H A R E D   S E R V I C E S   ###########
###########################################################################
    #                               Processing                                #
###########################################################################
    #
    #
    $BashFileName = "/tmp/build_daemon_all.out.bash$$";
    open( BASH, ">$BashFileName" )
      || die "     Error: Unable to open $BashFileName $!!\n\n";

    printf BASH "#!/bin/bash\n";
    printf BASH "#\n";
    printf BASH "#\n";
    printf BASH "#\n";
    printf BASH "#\n";
    printf BASH
"###########################################################################\n";
    printf BASH
"################  S P A W A R   S H A R E D   S E R V I C E S   ###########\n";
    printf BASH
"###########################################################################\n";
    printf BASH "#\n";
    printf BASH "#          File:  build_daemon_all.out.bash\n";
    printf BASH "#        Author:  Gene Brandt\n";
    printf BASH "#\n";
    printf BASH "#\n";
    printf BASH
"###########################################################################\n";
    printf BASH "#\n";
    printf BASH "#	Description:\n";
    printf BASH
      "#	Build one daemon.out file from all available daemon.raw files.\n";
    printf BASH "#\n";
    printf BASH "#\n";
    printf BASH "#\n";
    printf BASH "#\n";
    printf BASH "#\n";
    printf BASH
"###########################################################################\n";
    printf BASH
"################  S P A W A R   S H A R E D   S E R V I C E S   ###########\n";
    printf BASH
"###########################################################################\n";
    printf BASH
"#                            Environmentals                               #\n";
    printf BASH
"###########################################################################\n";
    printf BASH "#\n";
    printf BASH "#\n";
    printf BASH "\n";
    printf BASH "\n";
    printf BASH "\n";
    printf BASH "\n";
    printf BASH "#\n";
    printf BASH "#\n";
    printf BASH
"###########################################################################\n";
    printf BASH
"################  S P A W A R   S H A R E D   S E R V I C E S   ###########\n";
    printf BASH
"###########################################################################\n";
    printf BASH
"#                               Processing                                #\n";
    printf BASH
"###########################################################################\n";
    printf BASH "#\n";
    printf BASH "#\n";
    printf BASH "\n";
    printf BASH "printf \"\n\n\n     Building daemon_all.out\n\"\n";
    printf BASH "printf \"     =======================\n\n\"\n";
    printf BASH "sleep 3\n";
    printf BASH "cd /nsr/logs\n";
    printf BASH "printf \"     Saving existing data.\n\"\n";
    printf BASH "if [ -e daemon_all.out ]\n";
    printf BASH "then\n";
    printf BASH "sudo bash -c \"mv daemon_all.out daemon_all.pre\"\n";
    printf BASH "fi\n";
    printf BASH
"printf \"\n\n     Concatinaing the output of nsr_render_logs into daemon_all.pre\n\"\n";
    printf BASH "for rawfile in `ls -rt daemon*.raw`\n";
    printf BASH "do\n";
    printf BASH "printf \"     Rendering $rawfile\n\"\n";
    printf BASH
"sudo bash -c \"/usr/bin/nsr_render_log $rawfile >> daemon_all.pre 2> /dev/null\"\n";
    printf BASH "done\n";
    printf BASH "printf \"     Finalizing data in daemon_all.out\n\"\n";
    printf BASH "sudo bash -c \"sort -u daemon_all.pre -o daemon_all.out\"\n";
    printf BASH "printf \"     Removeing workfile daemon_all.pre\n\"\n";
    printf BASH "sudo bash -c \"rm daemon_all.pre\"\n";
    printf BASH "sudo bash -c \"chmod 644 daemon_all.out\"\n";
    printf BASH "ls -l daemon_all.out\n";
    printf BASH "\n";
    printf BASH "#\n";
    printf BASH "#\n";
    printf BASH
"###########################################################################\n";
    printf BASH
"################  S P A W A R   S H A R E D   S E R V I C E S   ###########\n";
    printf BASH
"###########################################################################\n";
    printf BASH
"#                               House Keeping                             #\n";
    printf BASH
"###########################################################################\n";
    printf BASH "#\n";
    printf BASH "#\n";
    close(BASH);
    chmod( 0755, $BashFileName );
}    #    End of gatherdata

sub ProcessRecord() {
    $RecRecord = shift;
    chomp($RecRecord);

# 71193 12/ 7/17 12:49:04 PM  0 0 0 1 1229 0 sscprodeng2 nsrd NSR info Recover Info: User root on nmpbsdbtst3 successfully recovered nmpbsdbtst3's files
#
#     Get the data fields that include spaces.
#
    $RecRecordDate = substr( $_, 6,  8 );
    $RecRecordTime = substr( $_, 16, 7 );
    $RecRecordAMPM = substr( $_, 24, 2 );
    #
    #     Grab the rest of the record information. I hope this doesn't change.
    #

    $RecRecorddata = substr( $_, 40 );
    if ($DEBUG) {
        printf "     Debug line: %3d Date: %s  ", __LINE__, $RecRecordDate;
        printf "     Debug line: %3d Time: %s  ", __LINE__, $RecRecordTime;
        printf "     Debug line: %3d ampm: %s\n", __LINE__, $RecRecordAMPM;
        printf "     Debug line: %3d data: %s\n", __LINE__, $RecRecorddata;
    }
    @RecordInfo = split( /:/, $RecRecorddata );
    if ($DEBUG) {
        printf "     Debug Line: %3d User: %s\n", __LINE__, $RecordInfo[1];
    }
    printf "     %3d %4s %9s %8s %s $RecordInfo[1]\n", $RecoverCount, $Notice,
      $RecRecordDate, $RecRecordTime, $RecRecordAMPM;
}    #     End of ProcessRecord

sub report_header() {

    printf "      EMC NetWorker recovers from available data.\n";
    printf "      === ======== ========= ==== ========= =====\n\n";
    printf "                 Report Date: $RPTDATE\n";
    printf "                 Report Time: $RPTTIME\n\n";
    printf "      Line       Date     Time       Details\n";
    printf "      ----       ----     ----       ";
    printf
"-------------------------------------------------------------------------------------------------------\n";
}    # End of report_header
#
#
###########################################################################
################  S P A W A R   S H A R E D   S E R V I C E S   ###########
###########################################################################
#                               House Keeping                             #
###########################################################################
#
#
unlink($BashFileName);