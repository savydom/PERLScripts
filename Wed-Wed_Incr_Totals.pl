#!/usr/bin/perl -w
# This utility is used to find the unremediated backups since 16:00 yesterday.
# This is used to create an automated rerun at 4:00 in the morning
# passing print to the script with just report and not update the group

use Time::Local;
#%convert_month_to_index = (Jan,0,Feb,1,Mar,2,Apr,3,May,4,Jun,5,Jul,6,Aug,7,Sep,8,Oct,9,Nov,10,Dec,11);
#%convert_month_to_txt = (0,Jan,1,Feb,2,Mar,3,Apr,4,May,5,Jun,6,Jul,7,Aug,8,Sep,9,Oct,10,Nov,11,Dec);
if (defined $ARGV[0] ) {
   $server =  $ARGV[0];
} else {
   $server = `/usr/bin/hostname`;
   chomp $server;
}

$date = `/usr/bin/date '+%y%m%d%H%M%S'`;
chomp $date;
my $networker = `/usr/bin/hostname`;
chomp $networker;
#$FAILADDRS='peter.reed.ctr\@navy.mil jeffrey.l.rodriguez.ctr\@navy.mil cody.p.crawford.ctr\@navy.mil';
#$FAILADDRS='peter.reed.ctr\@navy.mil';
#filename = "/home/scriptid/scripts/BACKUPS/daily_reports/$networker\_incr\_$date";
#print "Output filename=$filename\n";
#open (FAILMAIL,">$filename") or  die "Could not open $filename\n";
#print FAILMAIL "/usr/bin/mailx -s \'Backup Failures for $date on $networker\' $FAILADDRS <<ENDMAIL\n";
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
if ($last_wednesday > 10) {$last_wednesday -= 7};
# Start Seconds is based on Wednesday @ 16:00
$end_seconds_last_wednesday = $today_16 -$last_wednesday*24*3600;
$start_seconds_previous_wednesday = $end_seconds_last_wednesday-3600*24*7;
#print "Start seconds=$start_seconds_previous_wednesday, End Seconds= $end_seconds_last_wednesday\n";
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
#print "Start time=$start_time, End Time= $end_time\n";
(@return) = `/usr/sbin/mminfo -s $server -r totalsize -q 'level=incr,savetime>$start_time,savetime<$end_time'`;
$total = 0;
foreach $val (@return) {
   chomp $val;
   $total += $val;
}
$out = $total/1024/1024/1024/1024;
if (defined $ARGV[1]) {
   print "$out\n";;
} else {
   print "Total Full backups = $out\n";
}

