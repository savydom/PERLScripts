#!/usr/bin/perl -w
# This utility will determine the percent completions for backups.
# First pass is 5 incrementals and 1 full per week

use Time::Local;
unshift (@INC,"/home/scriptid/scripts/BACKUPS/SUBROUTINES");
require bit_manip;


#%convert_month_to_index = (Jan,0,Feb,1,Mar,2,Apr,3,May,4,Jun,5,Jul,6,Aug,7,Sep,8,Oct,9,Nov,10,Dec,11);
#%convert_month_to_txt = (0,Jan,1,Feb,2,Mar,3,Apr,4,May,5,Jun,6,Jul,7,Aug,8,Sep,9,Oct,10,Nov,11,Dec);


$date = `/usr/bin/date '+%y%m%d%H%M%S'`;
chomp $date;
#$FAILADDRS='peter.reed.ctr\@navy.mil jeffrey.l.rodriguez.ctr\@navy.mil cody.p.crawford.ctr\@navy.mil';
#$filename = "/home/scriptid/scripts/BACKUPS/daily_reports/$server\_incr\_$date";
#open (FAILMAIL,">$filename") or  die "Could not open $filename\n";
#print FAILMAIL "/usr/bin/mailx -s \'Backup Failures for $date on $server\' $FAILADDRS <<ENDMAIL\n";
#print FAILMAIL "Processes Savegroup Completions Looking for Backup Failures and Updates Group Automated-Daily-Reruns\n";

my $wday;
my $SUDO = '/usr/bin/sudo';
my $SSH  = '/usr/bin/ssh ';

#Want to process last Wednesday at 16:00 till Thursday at 16:00 and every day till current Wednesday at 16:00.
$seconds_since_1970 = time;
$start_hour=16;
#Compute Today at 16:00
($sec,$min,$hr,$wday) = (localtime($seconds_since_1970))[0,1,2,6];
$today_16 = $seconds_since_1970-$sec-$min*60 + ($start_hour-$hr)*3600;
#Compute Last Wednesday at 16:00
# Compute Previous Wednesday
$last_wednesday     = $wday + 4;
if ($last_wednesday > 6) {$last_wednesday -= 7};
# Start Seconds is based on Wednesday @ 16:00
$end_seconds_last_wednesday = $today_16 -$last_wednesday*24*3600;
$start_seconds_previous_wednesday = $end_seconds_last_wednesday-3600*24*7;
print "Start seconds=$start_seconds_previous_wednesday, End Seconds= $end_seconds_last_wednesday\n";
($day,$mon,$yr) = (localtime($start_seconds_previous_wednesday))[3,4,5];
$mon += 1;
#$mon = $convert_month_to_txt{$mon};
$yr += 1900;
$start_time = "$mon/$day/$yr 16:00:00";

($day,$mon,$yr) = (localtime($end_seconds_last_wednesday))[3,4,5];
$mon += 1;
#$mon = $convert_month_to_txt{$mon};
$yr += 1900;
$end_time = "$mon/$day/$yr 16:00:00";

print "Start time=$start_time, End Time= $end_time\n";

# Need to handle special cases for clients running longer than twelve
# Want the start time and the completion time for each day between the previous Wednesday at 16:00 to Thurday at 16:00.
(@return) = `/usr/sbin/mminfo -a -s sscprodeng -xc, -r 'client,name,level,nfiles,totalsize,nsavetime,sscomp(23)' -q 'savetime>$start_time,savetime<$end_time'`;
(@return1) = `/usr/sbin/mminfo -a -s sscprodeng2 -xc, -r 'client,name,level,nfiles,totalsize,nsavetime,sscomp(23)' -q 'savetime>$start_time,savetime<$end_time'`;
push (@return,@return1);
(@return) = sort { lc($a) cmp lc($b) || $a cmp $b } @return;

# We can now process return updating daily counts for backups 
# backup_incr{$client}, backup_full{$client}
# 0 is last Wednesday, 7 is Wednesday
# 0-Last Wednesday, 1-Last Thursday, 2-Last Friday, 3-Last Saturday, 4-Last Sunday, 5-Last Monday, 6-Last Tuesday, 7-Wednesday
#
# day of week = int((nsavetime - last wednesday seconds) / (3600*24) ) 
$start = $start_seconds_previous_wednesday;
$end   = $end_seconds_last_wednesday;
for $val (@return) {
    chomp $val;
    ($client,$filesystem,$level,$number_of_files,$totalsize,$starttime,$end_time) = split(/,/,$val);
    ($mon,$mday,$year,$hr,$min,$sec,$AP) = ($end_time =~ /(..)\/(..)\/(..) (\d\d):(\d\d):(\d\d) ?(\D\D)?/);
    if (defined $AP) {
      if ($AP =~ /PM/) {
         if ($hr < 12) {$hr += 12};
      }
    }

    $year+= 100;
    $mon -=1;
    if ($mon < 0) {
       print "MON:$val\n";
       next;
    }
    if ( ($hr < 0) || ($hr > 23) ) {
       print "Hr problem $val***\n";
       $hr = 0;
    }

    $end_secs = timelocal($sec,$min,$hr,$mday,$mon,$year);
    $delta = ($end_secs - $starttime)/3600;
    if ($delta > 18) { $slow_client{$client} = 1};
    next if ($client =~ /sscprodeng/);
    $day = int( ($starttime  - $start) / (3600*24));
    if ($day > 7) { print "Error: $day Date greater than 7\n"};
    if ( $level =~ /[iI][nN][cC][rR]/ ) {
       if (!defined $backup_incr{$client}) { $backup_incr{$client} = 0};
       $backup_incr{$client} = bit_manip($backup_incr{$client},$day,0);
       if ($delta >18) {$backup_incr{$client} = bit_manip($backup_incr{$client},$day+1,0);}
    } elsif ( $level =~ /[fF][uU][lL][lL]/ ) {
       if ( !defined $backup_full{$client} ) {$backup_full{$client} = 0};
       $backup_full{$client} = bit_manip($backup_full{$client},$day,0);
    } else {
       print "Level undefined for Client=$client\n";
    }
}
$ii = 1;
$good = 0;
$bad  = 0;
$fulls = 0;
$counti0 = 0;
$counti1 = 0;
$counti2 = 0;
$counti3 = 0;
$counti4 = 0;
$counti5 = 0;
$counti6 = 0;
$counti7 = 0;
$total=0;
foreach $client (sort keys %backup_incr) {
   $counti = bit_manip($backup_incr{$client}, 0, 1);
   print "$ii\t$client\tINCRS:$counti, ";
   if (defined $backup_full{$client}) {
      $countf = bit_manip($backup_full{$client}, 0, 1);
      print " FULLS:$countf";
      $fulls += 1;
   } else {
      print "No fulls";
   }
   if ($counti > 2 && $countf > 0) {
      $good += 1;
   } else {
      $bad += 1;
   }
   $ttt = $counti + $countf;
   if ($ttt > 4) {$total += 1};
   print "\n";
   ++$ii;
   if ($counti == 0) {$counti0 +=1}
   if ($counti == 1) {$counti1 +=1}
   if ($counti == 2) {$counti2 +=1}
   if ($counti == 3) {$counti3 +=1}
   if ($counti == 4) {$counti4 +=1}
   if ($counti == 5) {$counti5 +=1}
   if ($counti == 6) {$counti6 +=1}
   if ($counti == 7) {$counti7 +=1}
}
$success = $good/$ii*100;
$fails   = $bad/$ii*100;
print "Good:$good, $success\n";
print " Bad:$bad, $fails\n";
print "   No incrs=$counti0\n";
print "  One incrs=$counti1\n";
print "  Two incrs=$counti2\n";
print "Three incrs=$counti3\n";
print " Four incrs=$counti4\n";
print " Five incrs=$counti5\n";
print "  Six incrs=$counti6\n";
print "Seven incrs=$counti7\n";
print "Total Backups = $total\n";
$slow = scalar keys %slow_client;
print "Slow Clients= $slow\n";
print "Full client backups = $fulls\n";
