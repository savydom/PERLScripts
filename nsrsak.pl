#!/usr/bin/perl -w
# ----- Networker Swiss Army Knife -----
if (defined $ARGV[0]) {$input = $ARGV[0]};
if (defined $ARGV[1]) {$site = $ARGV[1]};
# The original report computes completions by week.
# The new report will be done by day.
# To minimize the number of tickets created, a sideline database will be created to maintain completions.A
# The database will include the skips so that there should be an entry for every day.
# Client status:
#	(c) completed
#	(w) completed with warnings 
#	(r) still running 
#	(s) skipped 
#	(f) failed
#	(u) unresolved
# Remedy ticket created date (julian date)
#	Assume a ticket will be opened no more than once per week 
# Data file one record per client use julian date and two digit year
# 	Keep tract of first run and last run and date
# 	Build record from pervious 28 days
#	Date id from yyjjj at 17:00 to yyjjj+1 at 17:00.  yyjjj is used as index. Most current is first.
#	days are separated by colons
#	since process by group, default on first run (notification run) is to set to still running
#	add field for last time remedy ticket created (If older than one week create another) or blank
# Record format
#       HEADER:number_of_days
#	server_name:last remedy:yyjjj(today),first client status,last client status:2nd to last early client status,2nd to last last client status:....
# Options:
#	build:x		- Build previous x days, set remedy ticket to 0, use all clients backed up for previous x days;
#			- Build will contain first and last data based on final results at yyjjj+1 at 17:00 
#	compress:x	- Keep x days
#       morning  	- Build the report from yyjjj at 17:00 till yyjjj+1 at 7:00
#       evening		- Fill in the last client status up till yyjjj+1 at 17:00
# 	*************  All reports come from data file not created as file is built and updated	
#       remedy		- Using status up till yyjjj+1 at 17:00 or when run create remedy tickets based on the results
#			- Make sure previous ticket is more than 1 week old
#	program		- Report on the success/failure by program
#	dcao		- Create DCAO report
#	validate	- Validate the information

use Time::Local;
(@SITES) = ('New Orleans',  'San Diego');
$EXCLUDE_GROUP = 'SDDATA';
(@servers) = ('sscprodeng', 'sdprodeng');
$SUDO = '/usr/local/bin/sudo';
$SSH  = '/usr/bin/ssh ';
#$MAILADDRS="peter.reed.ctr\@navy.mil";
#$MAILADDRS="peter.reed.ctr\@navy.mil brian.spragins.ctr\@navy.mil christopher.m.scully.ctr\@navy.mil";
$MAILADDRS="jennifer.piper.ctr\@navy.mil sondra.meek.ctr\@navy.mil peter.reed.ctr\@navy.mil brian.spragins.ctr\@navy.mil christopher.m.scully.ctr\@navy.mil jason.d.smith\@navy.mil jeffrey.l.rodriguez.ctr\@navy.mil eugene.brandt.ctr\@navy.mil";

# Get the current time
$seconds_from_1970 = time;

($sec,$min,$hr,$mday,$mon,$yr) = (localtime($seconds_from_1970))[0,1,2,3,4,5];
$mon=$mon+1;
if ($mon>12) {$mon=1};
$yr   =$yr+1900;
$mday = sprintf("%02d",($mday));
$mon  = sprintf("%02d",($mon));
$hr  = sprintf("%02d",($hr));
$min  = sprintf("%02d",($min));
$sec  = sprintf("%02d",($sec));
$now  = "$mon/$mday/$yr $hr:$min:$sec";
##print "$sec,$min,$hr,$mday,$mon,$yr,$wday\n";
%convert_month_to_index = (Jan,0,Feb,1,Mar,2,Apr,3,May,4,Jun,5,Jul,6,Aug,7,Sep,8,Oct,9,Nov,10,Dec,11);
	#%convert_month_to_txt = (0,Jan,1,Feb,2,Mar,3,Apr,4,May,5,Jun,6,Jul,7,Aug,8,Sep,9,Oct,10,Nov,11,Dec);
	#%convert_month = (Jan,0,Feb,1,Mar,2,Apr,3,May,4,Jun,5,Jul,6,Aug,7,Sep,8,Oct,9,Nov,10,Dec,11);

# New Dates
$seconds_from_1970  = time;
# Compute days ago
($wday)             = (localtime($seconds_from_1970))[6];
$last_wednesday     = $wday + 4;
# 
if ($last_wednesday > 10) {$last_wednesday -= 7};

WEEKS:
if (defined $ARGV[0]) {
   $number_of_reports = $ARGV[0];
} else {
   print "Enter number of weekly backup reports to generate:";
   $number_of_reports = <STDIN>;
   chop $number_of_reports;
   if ($number_of_reports>52 || $number_of_reports<1) {goto WEEKS};
}
# Last Thursday is week 1 so subtract 1
$number_of_weeks  = $number_of_reports - 1;
$week_seconds     = 7*24*3600;
$start_days_ago   = $last_wednesday + $number_of_weeks*7;
$start_seconds    = $seconds_from_1970 - $start_days_ago*24*3600; 
($mday,$mon,$yr) = (localtime($start_seconds))[3,4,5];
	#timelocal($ssec,$smin,$shr,$sday,$month(0-11),$syear(actual yr-1900);
	#$yesterday = timelocal(0,0,17,21,4,115);
	#$start_days_ago = 1;
$absolute_start_seconds = timelocal(0,0,17,$mday,$mon,$yr);
	#$absolute_start_seconds = $yesterday;
	#$start_seconds = $yesterday;
	#print "Start seconds=$start_seconds, Now=$seconds_from_1970\n";


LOCATION:
if (defined $ARGV[1]) {
   $loc = $ARGV[1];
} else {
   print "Enter (0) $SITES[0] or (1) $SITES[1], or (2) Both\n";
   $loc = <STDIN>;
   chop $loc;
   if (  ($loc < 0) || ($loc>2) ) { goto LOCATION};
}
if ($loc == 0){ 
   $list[0] = 0;
} elsif ($loc == 1){ 
   $list[0] = 1;
} elsif ($loc ==2) {
   (@list) = ('0','1');
}


#
# ----------------------- New Code ---------------------------------------
# Record format
#       HEADER:number_of_days
#	server_name:last remedy:yyjjj(yseterday),first client status,last client status,$full_at_last,$incr_at_last
#                  	:yyjjj(yesterday)2nd to last early client status,2nd to last last client status,$full_at_last,$incr_at_last
#                  	:3nd to last early client status,3nd to last last client status,$full_at_last,$incr_at_last
#                                 for each day
#
#	build:x		- Build previous x days, set remedy ticket to 0, use all clients backed up for previous x days;
#			- Build will contain first and last data based on final results at yyjjj+1 at 17:00 
#	compress:x	- Keep x days
#       morning  	- Build the report from yyjjj at 17:00 till yyjjj+1 at 7:00
#       evening		- Fill in the last client status up till yyjjj+1 at 17:00
# 	*************  All reports come from data file not created as file is built and updated	
#       remedy		- Using status up till yyjjj+1 at 17:00 or when run create remedy tickets based on the results
#			- Make sure previous ticket is more than 1 week old
#	program		- Report on the success/failure by program
#	dcao		- Create DCAO report
#	validate	- Validate the information

open (SUPPORT,"</nsr/local/Emails/data/ServerSupport.txt") or die "Could not open file /nsr/local/Emails/data/ServerSupport.txt\n";







#Loop on Number of reports
for ($i=0;$i<$number_of_reports;$i++) {
   $gtotalsize=$gtotalfiles=$gfilesystems=$gclients=0;
   ($mday,$mon,$yr) = (localtime($start_seconds))[3,4,5];
   #print "At top of loop $mday/$mon/$yr\n";
   $mon=$mon+1;
   if ($mon>12) {$mon=1};
   $yr   =$yr+1900;
   $mday = sprintf("%02d",($mday));
   $mon  = sprintf("%02d",($mon));
   $start_time = "$mon/$mday/$yr 17:00:00";
   $file_start = "$yr$mon$mday"."170000";
   $end_seconds= $start_seconds + $week_seconds;
   ($mday,$mon,$yr) = (localtime($end_seconds))[3,4,5];
   #print "At top of loop end time=$mday/$mon/$yr\n";
   $mon=$mon+1;
   if ($mon>12) {$mon=1};
   $yr   =$yr+1900;
   $mday = sprintf("%02d",($mday));
   $mon  = sprintf("%02d",($mon));
   $end_time = "$mon/$mday/$yr 17:00:00";
   if ($i == $number_of_weeks) {
      $check_end_wednesday = $absolute_start_seconds +  $week_seconds;
      if ($seconds_from_1970 < $check_end_wednesday) { $end_time = $now};
   }
   open(TMPFILE,">/nsr/local/WeeklyReports/$file_start") or die "Can't open file /nsr/local/WeeklyReports/$file_start";
   print TMPFILE "mailx -s 'DCAO NOLA NIPR Backup report for $start_time through $end_time' $MAILADDRS <<ENDMAIL\n";
   print TMPFILE "Backups for week beginning $start_time and ending $end_time\n";

   # Loop on sites
   foreach $index (@list) {
      undef %next_list;
      undef %last_group;
      #print "Backup Server index $index\n";
      undef %clientname;
      undef %unique; 
      $totalsize=$totalfiles=$filesystems=0;
      #print "mminfo -s $servers[$index] -xc, -a -r 'client,totalsize,name,nfiles' -q \"savetime>$start_time,savetime<$end_time\"\n";
      @return = `mminfo -s $servers[$index] -xc, -a -r 'client,totalsize,name,nfiles' -q "savetime>\'$start_time\',savetime<\'$end_time\'"`;
 
      # Loop on Mminfo
      foreach $val (@return) {
         chop $val;
         #print "Val from mminfo =$val\n";
         next if $val =~ /file/;
         ($client,$size,$name,$files) = split(/,/,$val);
         $client = lc($client);
         $key = "$client|$name";
         $unique{$key} = 1; 
         $clientname{$client} = 1;
         $totalsize+=$size;
         $totalfiles+=$files; 
         $filesystems+=1;
      }
      print TMPFILE "\n-------------------------------------------------\n\n";
      print TMPFILE "$SITES[$index] NIPR Backup Totals for Week\n"; 
      print TMPFILE " $start_time - $end_time\n";
      print TMPFILE "  (Remediated Failures included in totals)\n\n";
      #$totalsize = $totalsize/1024/1024/1024/1024/$number_of_weeks;
      $totalsize = $totalsize/1024/1024/1024/1024;
      $gtotalsize += $totalsize;
      #$totalfiles = $totalfiles/$number_of_weeks;
      $gtotalfiles +=  $totalfiles;
      $temp = format_number($totalsize,'2','l',12);
      print TMPFILE "      Total Tape Written = $temp TBs\n";
      $temp = format_number($totalfiles,'2','l',12);
      print TMPFILE "     Total Files Written = $temp\n";
      #$filesystems = $filesystems/$number_of_weeks;
      $gfilesystems += $filesystems;
      $number = keys %clientname;
      $gclients += $number;
      $temp = format_number($number,'2','l',12);
      print TMPFILE "       Number of clients = $temp\n";
      $temp = format_number($filesystems,'2','l',12);
      print TMPFILE "    File Systems Written = $temp\n";
      $count = keys %unique;
      $temp = format_number($count,'2','l',12);
      print TMPFILE " Total unique filsystems = $temp\n";
      $avgfs = $count/$number;
      $temp = format_number($avgfs,'2','l',12);
      print TMPFILE " Avg file systems/client = $temp\n";
      $avg_files = $totalfiles/$number;
      $temp = format_number($avg_files,'0','l',12);
      print TMPFILE " Avg files written/client= $temp\n";
      $avg_size = $totalsize*1024/$number;
      $temp = format_number($avg_size,'2','l',12);
      print TMPFILE "         Avg size/client = $temp GBs\n";
      $avg_size = $totalsize*1024*1024*1024/$totalfiles;
      $temp = format_number($avg_size,'2','l',12);
      print TMPFILE "           Avg file size = $temp KBs\n";
  
      $TOTAL=$DISABLED=$SUCCEEDED=$FAILED=$SUCCEEDED_WARN=$UNKNOWN=$UNRESOLVED=0;
      # Local or remote
      # Generate a list of files for the whole reporting period
      if ($index == 0) {
         #print "$SUDO /usr/bin/find /backup/nsr/Summaries -type f -mtime -$start_days_ago -exec /usr/bin/ls -1 \n";
        (@savegroups) = `$SUDO /usr/bin/find /backup/nsr/Summaries -type f -mtime -$start_days_ago -exec /usr/bin/ls -1 \{\} \\\;\"`;
      } else {
         #print "$SSH -q \"$SUDO /usr/bin/find /backup/nsr/Summaries -type f -mtime -$start_days_ago -exec /usr/bin/ls -1 \{\} \\\;\"\n";
        (@savegroups) = `$SSH -q sdprodeng \"$SUDO /usr/bin/find /backup/nsr/Summaries -type f -mtime -$start_days_ago -exec /usr/bin/ls -1 \{\} \\\;\"`;
      }

      # Process the save groups sort to gain all groups run between 17:00 and 17:00
      # Then sort by groups and keep the last group output for the day.  Should contain best data  
      # ADHOCs will need to be treated separately
      #/backup/nsr/Summaries/2015May18_232200_Mon_WSTD-P-2
      #2015May18_234200_Mon_WSTD-P-3
      #2015May18_234500_Mon_NavyNuclear

      undef @temp;
      my $day_of_week;
      #Build a list of values sorted by day between 17:00 and 17:00
      foreach $val (@savegroups) {
         chop $val;
         #print "Building list of Filenames=$val\n";
         $val =~ s:/backup/nsr/Summaries/::;
         ($syear,$smon,$sday,$shr,$smin,$ssec,$day_of_week,$sgroup) = ($val =~ /^(\d\d\d\d)(\D\D\D)(\d\d)_(\d\d)(\d\d)(\d\d)_(\D\D\D)_(.*)$/);
         # Convert each to seconds since 1970
         $month = $convert_month_to_index{$smon};
         $syear = $syear - 1900;
         $file_time = timelocal($ssec,$smin,$shr,$sday,$month,$syear);
         $record="$file_time,$sgroup,$val";
         #print "Push into temp $record\n";
         push (@temp,$record);
      }
      #@sorted = sort numerically @temp;
      @sorted = sort @temp;
      #Begin processing a day at a time
      ########################################### Fix this########################################
      $start_period=$absolute_start_seconds+$week_seconds*$i;
      #print "194 Start_period=$start_period\n";
      $end_day     = $start_period+24*3600;
      $end_week    = $start_period+24*3600*7+10;
      # Sorted contains the whole week
      #print "\n\nStart=$start_period, End Day=$end_day, End Week=$end_week\n";
      #($ysec,$ymin,$yhr,$ymday,$ymon,$yyr) = (localtime($start_period))[0,1,2,3,4,5];
      #print "Start time=$yyr,$ymon,$ymday,$yhr,$ymin,$ysec\n";
      #($ysec,$ymin,$yhr,$ymday,$ymon,$yyr) = (localtime($end_day))[0,1,2,3,4,5];
      #print "End Day=$yyr,$ymon,$ymday,$yhr,$ymin,$ysec\n";
      #($ysec,$ymin,$yhr,$ymday,$ymon,$yyr) = (localtime($end_week))[0,1,2,3,4,5];
      #print "End Week=$yyr,$ymon,$ymday,$yhr,$ymin,$ysec\n";
      $ii = -1; 
      foreach $val (@sorted) {
        $ii+=1; 
        ($filetime,$sgroup,$filename) = split(/,/,$val);
        # Take care of beginning
        #print "Before check Filetime from sorted =$filetime, Start_period= $start_period, End Day=$end_day, Filename=$filename\n";
        next if $filetime < $start_period;
        #print "After  check Filetime from sorted =$filetime, End Day=$end_day, Filename=$filename\n";
        #if ($ii = $#sorted) {$last_group{$sgroup} = $filename};
        next if ($filetime > $end_week);
        #print "215 II=$ii, Index on sorted=$#sorted Filetime=$filetime, End_day=$end_day\n";
        if ( ($filetime > $end_day) || ($ii == $#sorted) ) {
        #if ( ($filetime > $end_day)) {
           #print "\n\n-------------------------------\nEnd of Day\n-------------------------------\n\n";
           $start_period = $end_day;
           #print "217 Incrementing Start_period=$start_period\n";
           $end_day      = $start_period+24*3600;
           # Close out day, build file list for processing 
           undef @next_list;
           foreach $val2 (sort keys %last_group) { 
              push(@next_list,$last_group{$val2});
              #print "Last group for $val2=$last_group{$val2}\n";
           }

           #NetWorker savegroup: (notice) VADP-PRODPRIV-ZONE2 completed, Total 32 client(s), 32 Succeeded. See group completion details for more information.
           # Process the last group list for the current day
           foreach $vval (@next_list) {
              #print "Processing file vval $vval\n";
              if ($index == 0) {
                 #print "$SUDO /usr/bin/egrep -e 'NetWorker savegroup'  -e '^Failed:' -e ' Succeeded with warning' /backup/nsr/Summaries/$vval\n";
                 (@savegroups) = `$SUDO /usr/bin/egrep -e 'NetWorker savegroup'  -e '^Failed:' -e ' Succeeded with warning' /backup/nsr/Summaries/$vval"`;
              } else {
                 #print "$SSH -q sdprodeng \"$SUDO /usr/bin/egrep -e 'NetWorker savegroup'  -e '^Failed:' -e ' Succeeded with warning' /backup/nsr/Summaries/$vval\"\n";
                 (@savegroups) = `$SSH -q sdprodeng \"$SUDO /usr/bin/egrep -e 'NetWorker savegroup'  -e '^Failed:' -e ' Succeeded with warning' /backup/nsr/Summaries/$vval\""`;
              }

              # Process a group file
              foreach $val (@savegroups) {
                 #print "Processing file $vval\n";
                 next if $val =~ /^Succeeded with warning/;
                 $skip = 0;
                 if ($val =~ /$EXCLUDE_GROUP/) {$skip=1};
                 $val =~ s/^NetWorker savegroup: .*\, Total //;
                 #$val =~ s/^NetWorker savegroup: \(\D+\) //;
                 $val =~ s/\. See group completion details for more information\.//;
                 (@values) = split(/,/,$val);
                 #print "VAL above sums=$val\n";
                 chop $val;
                 foreach $vvv (@values) {
                    if ($vvv =~ /\d+ client\(s\)/) {
                       ($total) = ($vvv =~ /(\d+) client\(s\)/);
                       #print "\tTotal=$total\n";
                       $TOTAL+=$total;
                    } elsif ($vvv =~ /Disabled/) {
                       ($disabled) = ($vvv =~ /\s*(\d+) Clients Disabled/);
                       #print "\ttdisabled=$disabled\n";
                       $DISABLED += $disabled;
                    } elsif ($vvv =~ / Succeeded with warning/) {
                       $succeeded_warn=0;
                       ($succeeded_warn) = ($vvv =~ /\s*(\d+) Succeeded with warning\(s\)/);
                       if (!defined $succeeded_warn) { $succeeded_warn=0};
                       #print "\tsucceeded with warn=$succeeded_warn\n";
                       $SUCCEEDED_WARN +=$succeeded_warn;
                    } elsif ($vvv =~ /Succeeded/) {
                       ($succeeded) = ($vvv =~ /\s*(\d+) Succeeded/);
                       #print "\tsucceeded=$succeeded\n";
                       $SUCCEEDED +=$succeeded;
                    } elsif ($vvv =~ /Failed/) {
                       ($failed) = ($vvv =~ /\s*(\d+) Failed/);
                       #print "\tfailed=$failed\n";
                       # Kludge to eliminate penalty for San Diego Coop
                       if ($skip == 0) {
                          $FAILED += $failed;
                       } else {
                          $SUCCEEDED_WARN += $failed;
                       }
                    } elsif ($vvv =~ /Unresolved/) {
                       ($failed) = ($vvv =~ /\s*(\d+) Hostname.*$/);
                       #print "\tfailed=$failed\n";
                       $UNRESOLVED += $failed;
                    } else {
                       print "\tDon't know $vvv\n";
                       $UNKNOWN +=1;
                    }
                 }
              }
              # End of process a single group file
           }
           #$start_period = $end_day;
           #print "288 Start_period=$start_period\n";
           #$end_day      = $start_period+24*3600;
           #print "\n\nStart=$start_period, End Day=$end_day, End Week=$end_week\n";
           #($ysec,$ymin,$yhr,$ymday,$ymon,$yyr) = (localtime($start_period))[0,1,2,3,4,5];
           #print "Start time=$yyr,$ymon,$ymday,$yhr,$ymin,$ysec\n";
           #($ysec,$ymin,$yhr,$ymday,$ymon,$yyr) = (localtime($end_day))[0,1,2,3,4,5];
           #print "End Day=$yyr,$ymon,$ymday,$yhr,$ymin,$ysec\n";
           #($ysec,$ymin,$yhr,$ymday,$ymon,$yyr) = (localtime($end_week))[0,1,2,3,4,5];
           #print "End Week=$yyr,$ymon,$ymday,$yhr,$ymin,$ysec\n";
           undef %last_group;
           # End of day processing
        } else {
           # Processing the same day, array will contain last instance of group for the day
           #print "Group in last group = $sgroup, $filename\n";
           $last_group{$sgroup} = $filename;
        }
        # End of day loop
      }
      # End of process week loop

      #print "SUCCEEDED=$SUCCEEDED, SUCCEEDED_WARN=$SUCCEEDED_WARN, DISABLED=$DISABLED, FAILED=$FAILED\n";
 
      $temp = format_number($TOTAL,'2','l',12);
      print TMPFILE "\n    Total Client Backups = $temp\n";
      $temp = format_number($SUCCEEDED,'2','l',12);
      print TMPFILE "               Succeeded = $temp\n";
      $temp = format_number($SUCCEEDED_WARN,'2','l',12);
      print TMPFILE "          Succeeded/Warn = $temp\n";
      $temp = format_number($DISABLED,'2','l',12); 
      print TMPFILE "                Disabled = $temp\n";
      $temp = format_number($FAILED,'2','l',12);
      print TMPFILE "                  Failed = $temp\n";
      $temp = format_number($UNKNOWN,'2','l',12);
      print TMPFILE "                 Unknown = $temp\n";
      $temp = format_number($UNRESOLVED,'2','l',12);
      print TMPFILE "              Unresolved = $temp\n";
      $temp = $SUCCEEDED/($TOTAL-$DISABLED)*100;
      $temp = format_number($temp,'2','l',12);
      print TMPFILE "\n       Percent Completed = $temp%\n";
      $temp = ($SUCCEEDED+$SUCCEEDED_WARN)/($TOTAL-$DISABLED)*100;
      $temp = format_number($temp,'2','l',12);
      print TMPFILE "  Percent Completed/warn = $temp%\n";
      $temp = $FAILED/($TOTAL-$DISABLED)*100;
      $temp = format_number($temp,'2','l',12);
      print TMPFILE "          Percent Failed = $temp%\n";
   }
   # End of site loop

   print TMPFILE "\n-------------------------------------------------\n\n";
   print TMPFILE "New Orleans NIPR Rollup Totals $start_time\n";
   $temp = format_number($gclients,'0','l',12);
   print TMPFILE "           Total Clients = $temp\n";
   $temp = format_number($gtotalsize,'2','l',12);
   print TMPFILE "    Total Client Backups = $temp TBs\n";
   $temp = format_number($gtotalfiles,'2','l',12);
   print TMPFILE "             Total Files = $temp\n";
   $temp = format_number($gfilesystems,'2','l',12);
   print TMPFILE "       Total Filesystems = $temp\n";
   print TMPFILE "ENDMAIL\n";
   close TMPFILE;
   $return = `/usr/bin/sh  /nsr/local/WeeklyReports/$file_start > /dev/null 2>&1`;
   $start_seconds += $week_seconds;
   $start_days_ago -= 7;
}

sub format_number {
   my ($val,$places,$justify,$width) = @_;
   my $text1;
   $text=reverse $val;
   $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
   $val=reverse $text;
   $val =~ s/(\d*\.\d{$places})\d*/$1/;
   $length = length($val);
   if ($justify eq 'l') {
      $start = 0;
   } elsif ($justify eq 'c') {
      $start = int( ($width-$length)/2 );
   } elsif ( $justify eq 'r') {
      $start = $width-$length;
   } else {
      print "Error in formatnumber\n";
  }
   $final = ' ' x $width;
   substr($final,$start,$length)=$val;
   if ($justify =~ /l/) {$final =~ s/\s+$//};
   $final = commify($final);
   return $final;
}
sub commify {
     my $text = reverse $_[0];
     $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
     return scalar reverse $text;
}

#sub numerically {$a <=> $b; }

# -------------------- Used to read command line or perform client input ----------------- 
sub input_arg {
    if (defined ($ARGV[0]) {
       $input = ($ARGV[0];
    } else {
        OPT:
        print "Options:\n"
	print "\tbuild\tBuild data file for a previous amount of days\n";
        print "\tcompress\tCompress existing data file to x amount of days\n";
	print "\tmorning\tUpdate data file with info previous day at 17:00 till today at 7:00\n";
        print "\tevening\tUpdate data file with info for previous day at 17:00 till today at 17:00\n";
        print "\tremedy\tCreate remedy tickets based on evening report\n";
	print "\tprogram\tCreate reports based on programs\n";
	print "\tdcao\tCreate DCAO weekly report usually at 17:00 in each wednesday\n";
        print "\tvalidate\tValidate support data in /nsr/local/Emails/data/ServerSupport.txt\n";
        print "Enter a single option (build...., or the first letter of the option) : ";
        $option = <STDIN>;
        chomp $option;
        $option = lc($option);
        
        if ($option =~ /build/ || $option =~ /^b/) {
	   print "This will rebuild the data file\n";
           print "Enter the number of previous days to build : ";
           $days = <STDIN>;
           chomp $days;
           $input = "build,$days";

	} elsif (($option =~ /compress/ || $option =~ /^c/) {
	   print "This will reduce the number of days retained in the data file to x days\n";
           print "Enter the number of previous days to retain : ";
           $days = <STDIN>;
           chomp $days;
           $input = "compress,$days";

	} elsif (($option =~ /morning/ || $option =~ /^m/) {
	   print "This will update all client records based on group completion information from\n";
	   print "\tyesterday at 17:00 till today at 7:00";
           $input = "morning";

	} elsif (($option =~ /evening/ || $option =~ /^e/) {
	   print "This will update all client records based on group completion information from\n";
	   print "\tyesterday at 17:00 till today at 17:00";
           $input = "evening";

	} elsif (($option =~ /remedy/ || $option =~ /^r/) {
	   print "This will create remedy tickets for failed backups based on client records from\n";
	   print "\tyesterday at 17:00 till today at 17:00";
           $input = "remedy";

	} elsif (($option =~ /program/ || $option =~ /^p/) {
           # all is an option 
	   print "This will create an output report by requested program for an input period\n";
	   print "\tEnter program name : ";
           $program = <STDIN>;
           chomp $program; 
           print "\tEnter the number of previous days to report : ";
           $days = <STDIN>;
           chomp $days;
           $input = "program,$program,$days";

	} elsif (($option =~ /dcao || $option =~ /^d//) {
	   print "This will create the weekly DCAO report usually scheduled for Wednesdays at 17:00\n";
           $input = "dcao";
	} elsif (($option =~ /validate/ || $option =~ /^v/) {
	   print "This will validate that the /nsr/local/Emails/data/ServerSupport.txt file has entries\n";
           print "\tfor each server being backed up\n";
           $input = "validate";
        } else {
	   print "Illegal option $option\n\t Reenter option\n";
           goto OPT;
        }
    }
    
    # validate arguments 
    if ( ($input =~ /build/) || ($input =~ /compress/) ) {
       ($command,$days_to_process) = split(/,/,$input);
       $program = '';
    } elsif ($input =~ /program/) {
       ($command,$program,$days_to_process) = split(/,/,$input); 
    } else {
       $command = $input;
       $program = '';
       $days_to_process=0;
    }
}


sub mail_out {
   ($nsr_server,@failed_servers) = @_;
   %seen = ();
   undef @uniq;
   foreach $item (@failed_servers) {
      push (@uniq,$item) unless $seen{$item}++;
   }

   print "Inside mail out $nsr_server\n";
   open (SUPPORT,"</nsr/local/Emails/data/ServerSupport.txt") or die "Could not open file /nsr/local/Emails/data/ServerSupport.txt\n";
   undef (%mailgroup);
   undef (%backup_type);
   undef (%grouped);
   undef (%failed_groups);
   undef (%running_group);
   foreach $val (<SUPPORT>) {
      next if $val =~ /^\s*$/;
      next if $val =~ /^\s*#/;
      chomp $val;
      my ($server,$tgroup) = split(/,/,$val);
      $server = lc($server);
      $mailgroup{$server} = $tgroup;
   }
   #print "Below support.txt\n";
   (@nsradmin) = `/usr/sbin/nsradmin -s $nsr_server -i /nsr/local/Emails/backup_command.cmd`;
   foreach $val (@nsradmin) {
      next if $val =~ /Current Query Set/;
      next if $val =~ /^\s*$/;
      chomp $val;
      if ($val =~ /name:/) {
         $host = $val;
         $host = lc($host);
         $host =~ s/\s*name: //;
         $host =~ s/\;//;
      } elsif ($val =~ /backup command/) {
         if ($val =~ /nsrvadp/) {
            $backup_type{$host} = '  VADP';
         } else {
            $backup_type{$host} = 'STANDARD';
         }
         #print "Host=$host, Type=$backup_type{$host}\n";
      }
   }

   #$address='NEDCSupport\@navy.mil';
   #$subject='**P/A - (ADMINS) Backup Remediation';
   $signature="Peter Reed\nContractor, aVenture Technologies\n2251 Lakeshore Drive\nSPAWAR Systems Center Atlantic\nNew Orleans Office";

   #print "Building list of servers backed up\n";
   #(@backup_clients)=`/usr/sbin/mminfo -r client -q 'savetime>last week' | /usr/bin/uniq `;
   #foreach $server (@backup_clients) {
   #   chop $server;
   #   $server = lc($server);
   #   #$check{$server} = 1;
   #   if (!defined $mailgroup{$server}) {
   #      print "Server $server has no mail group assigned\n";
   #   }
   #}
   foreach $val (@uniq) {
      $temp = $val;
      $temp =~ s/^\s+//;
      my ($failed,$groupee) = split(/\(/,$temp);
      $failed =~ s/\s+$//;
      $failed = lc($failed);
      #print "Failed=***$failed***\n";
      $running_group{$failed} = $groupee;
      if (defined $mailgroup{$failed}) {
         $mgroup = $mailgroup{$failed};
      } else {
         $mgroup = 'None';
         #print "********No mail group assigned for $failed\n";
      }
      # List of client by mail group
      if (defined $grouped{$mgroup}) {
         $grouped{$mgroup} = "$grouped{$mgroup}:$failed";
      } else {
         $grouped{$mgroup} = $failed;
      }
      $failed_groups{$mgroup} = 1;
   }
   foreach $tgroup (sort keys %failed_groups) {
      #print "Mail Group=$tgroup\n";
      print TMPFILE "\n   --------------------------- M A I L  G R O U P:  $tgroup ---------------------------\n";
      print TMPFILE "   Server          \t\t\tDNS CHECK  \tSTATUS  PROGRAM  \tBackup Type    \tBACKUP GROUP      \tNetworker Software\n";
      print TMPFILE "   ------          \t\t\t---------  \t------  \t\t-------  \t\t-----------  \t----------------    \t------------------\n";
      # print "Above tgroup processing $tgroup, # of servers = $#list_of_failed\n";
      (@list_of_failed) = split(/:/, $grouped{$tgroup});
      foreach $server (@list_of_failed) {
        $ping = pinger($server);
        if ($ping =~ /up/) {
           $port = testport($server,7937);
        } else {
           $port = 'Client not listening';
        }
        $dns = resolv_name($server);
        $program = check_program($server);
        $return = build_output($server,$dns,$ping,$port,$backup_type{$server},$running_group{$server},$program,140);
        $ADDRESS="peter.reed.ctr\@navy.mil brian.spragins.ctr\@navy.mil jeffrey.l.rodriguez.ctr\@navy.mil";
        if ( $remedy == 1 ) {
           open(REMEDY,">/nsr/local/Emails/$server") or die "Can't open file /nsr/local/MorningReports/$server\n";
           print REMEDY "mailx -s \'Create SR for backup failure of $server\' $ADDRESS<<ENDMAIL\n";
           print REMEDY "Helpdesk,\nPlease create a Service Request for remdiation of backup problems and put in the $tgroup\'s Group\n\n";
           print REMEDY "Customer: Rodriguez, Jeffrey\n\n";
           print REMEDY "Subject: Backup failed for server \"$server\"\n\n";
           print REMEDY "Description:\n\n";
           print REMEDY "\n      Server          \tDNS CHECK  \tSTATUS  \tPROGRAM  \tBackup Type    \tBACKUP GROUP     \tNetworker Software\n";
           print REMEDY "      ------          \t---------  \t------  \t-------  \t-----------  \t----------------    \t------------------\n";
           print REMEDY "   $return\n\n";
           print TMPFILE "   $return";
           print REMEDY "(DETAILS TAB)\n";
           print REMEDY "System: NEW ORLEANS NAVY DATA CENTER (NEDC)\n\n";
           print REMEDY "Component: SUSTAINMENT\n\n";
           $pppp = uc($program);
           print REMEDY "Item: \($pppp\)\n\n";
           print REMEDY "Call Code: Internet\n\n";
           print REMEDY "(ACTIVITY TAB)\n";
           print REMEDY "Work History: Created SR because of backup failure\n\n";
           print REMEDY "Assigned Group: $tgroup\n";
           print REMEDY "\n\n$signature\n";
           print REMEDY "ENDMAIL\n";
           close REMEDY;
           $return = `/usr/bin/sh  /nsr/local/Emails/$server 2>&1/dev/null`;
        }

        print TMPFILE "$return\n";
      }
   }
   return $return;
}
sub build_output{
   my ($host,$dns,$ping,$port,$type,$groupee,$program,$width) = @_;
   $final = ' ' x $width;

   substr($final,1,20)=$host;
   substr($final,20,1)="\t";
   substr($final,20,9)=$dns;
   substr($final,31,1)="\t";
   substr($final,32,6)=$ping;
   substr($final,38,1)="\t";
   $program = uc($program);
   substr($final,39,15)=uc($program);
   substr($final,48,1)="\t";
   if (defined $type) {
      substr($final,49,11)=$type;
      substr($final,58,2)="\t\t";
   }
   $ggg = $groupee;
   $ggg =~ s/\)//;
   substr($final,60,15)=$ggg;
   substr($final,79,1)="\t";
   substr($final,80,23)=$port;
   $final = "$host\t\t$dns\t$ping\t$program\t$type\t$ggg\t\t\t$port";
   return $final;
}

sub check_program {
   my ($host) = @_;
   $program = lc($host);
   if ($server =~ /^c27/) {
      $program =~ s/c27//;
      $program =~ s/cnla.*$//;
      $program =~ s/spsc.*$//;
      $program =~ s/netc.*/NETC/;
   } else {
      $program =~ s/prd.*$//;
      $program =~ s/tst.*$//;
      $program =~ s/db.*$//;
      $program =~ s/app.*$//;
      $program =~ s/cnla.*$//;
      $program =~ s/spsc.*$//;
      if ($program =~ /^ssc/) {$program='CSA';
      } elsif ($program =~ /^sd/) {$program='CSA-U';
      } elsif ($program =~ /^pd2/) {$program='CSA-U';
      } elsif ($program =~ /^ace/) {$program='ACE';
      } elsif ($program =~ /^itc/) {$program='CMS';
      } elsif ($program =~ /^cms/) {$program='CMS';
      } elsif ($program =~ /^mywm/) {$program='ACE';
      } elsif ($program =~ /^nmpbs/) {$program='NMPBS';
      } elsif ($program =~ /^csams/) {$program='CSAMS';
      } elsif ($program =~ /^rhs/) {$program='RHS';
      } elsif ($program =~ /^sem/) {$program='SEMS';
      } elsif ($program =~ /^nola/) {$program='CSA-WINDOWS';
      } elsif ($program =~ /^sanmgmt/) {$program='CSA-WINDOWS';
      } elsif ($program =~ /^uivm/) {$program='CSA-WINDOWS';
      } elsif ($program =~ /^anal/) {$program='CSA-WINDOWS';
      } elsif ($program =~ /^vc/) {$program='CSA-W';
      } elsif ($program =~ /^ssc/) {$program='CSA-NSO';
      } elsif ($program =~ /^nso/) {$program='CSA-NSO';
      } elsif ($program =~ /^lems/) {$program='CSA-NSO';
      } elsif ($program =~ /^sccv/) {$program='CSA-NSO';
      } elsif ($program =~ /^jalis/) {$program='CSA-UNIX';
      } elsif ($program =~ /^coopns/) {$program='CSA-UNIX';
      } elsif ($program =~ /^nrows/) {$program='CSA-UNIX';
      } elsif ($program =~ /^mrrs/) {$program='CSA-UNIX';
      } elsif ($program =~ /^rmmco/) {$program='CSA-UNIX';
      } elsif ($program =~ /^dia/) {$program='CSA-NSO';
      } elsif ($program =~ /^sepm/) {$program='CSA-NSO';
      } elsif ($program =~ /^oem/) {$program='CSA-DBA';
      } elsif ($program =~ /^bkp/) {$program='CSA-BACKUPS';
      } elsif ($program =~ /^ldap/) {$program='CSA-UNIX';
      } elsif ($program =~ /^ns\d/) {$program='CSA-UNIX';
      } elsif ($program =~ /^apache/) {$program='CSA-UNIX';
      } elsif ($program =~ /^prod/) {$program='CSA';
      } elsif ($program =~ /^mgmt/) {$program='CSA';
      } elsif ($program =~ /^monperf\d/) {$program='CSA-SOLARWINDS';
      } elsif ($program =~ /.*-c$/) {$program='CSA-SOLARWINDS';
      } else {
        $program = '????';
      }
      $program = uc($program);
  }
  return $program;
}



