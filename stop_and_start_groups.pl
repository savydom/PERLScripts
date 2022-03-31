#!/usr/bin/perl -w
# This routine is used primarily for maintenance weekend when all currently running jobs 
# 	need to be stopped.  They will also need to be restarted or started.
# The routine will determine what to do based on the total outage time which it requests
# VADP startup and stops will be spaced out to prevent overloading the SAN.
# Regular backups will just be started or stopped with minimal spacing.
# Because jobs can be started or restarted on different days the program will use the comment 
#	field in the group to determine the level to be used.
# Since backups are based on start time, that day will be used as the basis for the backup
# The standard groups will be started 2 minutes apart and the VADP groups 5 or 10 minutes apart.
# Group parallelism will also need to be factored into the equation so that we don't overdrive
#	the server parallelism
# Standard backup to VADP ratio should be set
#	UNIX/LINUX backup will start almost immediately
#	VADP has to create metafiles before actual backups start
# Use at to schedule the start of the jobs
#	/usr/bin/at -k -f source_file -t time can use STDIN instead of a file 
#		time hh:mm
#
#	/usr/sbin/savegrp -G groupname -l level -c client -N parallelism 	# Start a group
#	/usr/sbin/savegrp -R groupname -l level -c client -N parallelism	# Restart a group 
# 
# Control Settings:
use Time::Local;
print "Enter the start and end time for the outage.\n";
print "These times will be used to determine which groups ran and which didn't\n";
print "Enter the start time for the outage (mmddyy:hhmmss) : ";
$start_outage = <STDIN>;
if ($start_outage =~ /^\s*$/) {$start_outage='090915:190000'}
# Convert time to epoch seconds
my ($m,$d,$y,$h,$mi,$s) = ($start_outage =~ m/\s*(\d\d)(\d\d)(\d\d):(\d\d)(\d\d)(\d\d)/);
$y+= 100;
$m -= 1;
$start_outage = timelocal($s,$mi,$h,$d,$m,$y);
# Base the starts and restarts on the beginning of the outage
# Have to worry about starts after midnight
$start_day_of_week = (Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday)[(localtime($start_outage))[6]];
print "Enter the end time for the outage   (mmddyy:hhmmss) : ";
$end_outage = <STDIN>;
if ($end_outage =~ /^\s*$/) {$end_outage='090915:230000'}
($m,$d,$y,$h,$mi,$s) = ($end_outage =~ m/\s*(\d\d)(\d\d)(\d\d):(\d\d)(\d\d)(\d\d)/);
#print "$m,$d,$y,$h,$mi,$s\n";
$y+= 100;
$m -= 1;
$end_outage = timelocal($s,$mi,$h,$d,$m,$y);
#print "Start Outage=$start_outage End Outage=$end_outage\n";

$SERVER_PARALLELISM = 350;	# This can be different than the real parallelism
$UNIX_CLIENTS_PER_HOUR = 60;	# Use this number to control how many runs start so that all UNIX
				# Doesn't run at same time
$VADP_CLIENTS_PER_HOUR = 100;	# Use this number to compute the delta start times
$PRODUCTION_FIRST = 'y';

# Gather all the information required from the groups ignoring disabled groups
# Want name, autostart, comment, start time, last start, last end, savegrp parallelism 
#
#                        type: NSR group;
#                        name: citrix;
#                     comment: ;
#                   autostart: [Enabled]   Disabled    Start now ;
#                  start time: "22:59";
#                  last start: "Tue Sep  1 13:38:45 2015";
#                    last end: "Tue Sep  1 15:24:40 2015";
#                  next start: "Tue Sep  1 22:59:00 2015";
#	 savegrp parallelism: 0;
#   $val = ". type:NSR schedule'\n'show name\\;action'\n'print";
#   @return = `/usr/bin/echo $val | /usr/sbin/nsradmin -i -`;
#$val = ". type:NSR group'\n'show name'\n'print";
$val = ". type:NSR group'\n'show name\\;autostart\\;comment\\;start time\\;last start\\;last end\\;savegrp parallelism\\;action'\n'print";
print "Before nsradmin\n";
@return = `/usr/bin/echo $val | /usr/sbin/nsradmin -i -`;
print "After nsradmin\n";
#                       name: NavyNuclear;
#
#                     comment: ;
#
#                   autostart: Enabled;
#
#                  start time: "23:10";
#
#                  last start: "Mon Aug 31 23:10:00 2015";
#
#                    last end: "Mon Aug 31 23:55:49 2015";
#
#         savegrp parallelism: 50;
#
#
#
#                        name: SDDATA;
#
#                     comment: ;
#
#                   autostart: Enabled;
#
#                  start time: "19:20";
#
#                  last start: "Mon Aug 31 19:20:00 2015";
#
#                    last end: "Tue Sep  1 10:40:30 2015";
#
#         savegrp parallelism: 45;
#
$minimum = 10000000;
foreach $val (@return) {
   chomp $val;
   $val =~ s/\;//;
   next if $val =~ /^\s*$/;
   if ($val =~ /name:/) {
      $val =~ s/\s*name: //;
      $name = $val;
   } elsif ($val =~ /autostart/) {
      $val =~ s/\s*autostart: //;
      $autostart{$name} = $val;
   } elsif ($val =~ /comment/) {
      $val =~ s/\s*comment: //;
      $comment{$name} = $val;
   } elsif ($val =~ /start time/) {
      $val =~ s/\s*start time: //;
      $val =~ s/"//g;
      # Convert start time minutes since Midnight
      ($hour,$min) = split(/:/,$val);
      $min_from_mid = int($hour)*60 + int($min);
      # Check for less than 2PM
      if ($min_from_mid < 840) {$min_from_mid += 2400};
      if ($min_from_mid < $minimum) {$minimum=$min_from_mid};
      $start_time{$name} = $min_from_mid;
   } elsif ($val =~ /last start/) {
      $val =~ s/\s*last start: //;
      ($time,$day_of_week) = convert_time($val);
      $last_start{$name} = $time;
      $original_start_day{$name} = $day_of_week;
   } elsif ($val =~ /last end/) {
      $val =~ s/\s*last end: //;
      ($time,$day_of_week) = convert_time($val);
      $last_end{$name} = $time;
   } elsif ($val =~ /parallelism/) {
      $val =~ s/\s*savegrp parallelism: //;
      $parallelism{$name} = $val;
   } else {
      print "What is this $val\n";
   }
}
#Group name:VADP-TRANSDEV3-P2, FRIDAY, Enabled, "19:03","Tue Sep  8 19:03:00 2015", "Tue Sep  8 19:12:21 2015",10
#Group name:VADP-TRANSDEV4-P1, FRIDAY, Enabled, "19:04","Tue Sep  8 19:04:00 2015", "Tue Sep  8 19:12:23 2015",10
#Group name:VADP-TRANSPROD-P2, FRIDAY, Enabled, "19:06",, ,10
#Group name:VADP-TRANSQA-P1, FRIDAY, Enabled, "19:10","Tue Sep  8 19:10:00 2015", "Tue Sep  8 19:12:20 2015",10
#

foreach $name (sort keys (%autostart)) {
   $level='incr';
   if ( ($last_start{$name} > $start_outage) && ($last_start{$name}<$end_outage) ) {
      print "Job $name should have started during outage window\n";
      if ( $start_day_of_week =~ $comment{$name}) {$level='full'};
      `/usr/bin/echo  "***************/usr/sbin/savegrp -G $name -l $level"`; 	# Start a group
   } elsif ( $last_end{$name} == 0 ) {
      print "Job $name was running at the start of the outage window and should be restarted\n";
      if ($original_start_day{$name} =~ /$comment{$name}/) {$level='full'};
      `/usr/bin/echo "*********************/usr/sbin/savegrp -R $name -l $level"`;	# Restart a group 
   }
   $delta = $start_time{$name} - $minimum;
   print "Name:$name, Start time:$delta\n";
   #if ($name =~ /ADHOC-Full/) {print "***********Group name:$name, $comment{$name}, $autostart{$name}, $start_time{$name},$last_start{$name}, $last_end{$name},$parallelism{$name}\n"};
}
sub convert_time {
   my ($time) = @_;
   $epoch_secs=0;
   #print "In Convert time=***$time***\n";
   if ($time =~ /^\s*$/) {
      print "Found a blank time\n";
      $wwday= 'Sun';
      goto RETURN;
   }
   # First position is index,value...
   %convert_month_txt_to_index = (Jan,'0',Feb,'1',Mar,'2',Apr,'3',May,'4',Jun,'5',Jul,'6',Aug,'7',Sep,'8',Oct,'9',Nov,'10',Dec,'11');
   %convert_day_short_to_long = (Sun, 'Sunday' ,Mon, 'Monday' ,Tue, 'Tueday' ,Wed, 'Wednesday' ,Thu, 'Thursday' ,Fri, 'Friday' ,Sat, 'Saturday');
   #"Wed Sep  9 23:20:00 2015"
   my ($wwday,$month,$day,$hr,$min,$sec,$year) = ( $time =~ m/\"(\D\D\D)\s+(\D\D\D)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d+)\"/ );
   #print "$wwday,$month,$day,$hr,$min,$sec,$year\n";
   $year -= 1900;
   $month = $convert_month_txt_to_index{$month}; 
   ##print "Month=$month\n";
   $epoch_secs = timelocal($sec,$min,$hr,$day,$month,$year);
   #$today = time;
   #print "Today=$today, $epoch_secs \n";
   RETURN:
   #print "WDAY=**$wwday***\n";
   return $epoch_secs,$convert_day_short_to_long{$wwday};
}
