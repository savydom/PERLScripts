#!/usr/bin/perl -w
# This utility will capture output from savegroup completions and then create a data file to be used for processing
# various reports.  The records will contain fields semi colon delimited:
# group name
# backup server
#	1 = sscprodeng
#	2 = sscprodeng2
# start time (time since 1970)
# end time (time since 1970)	
# Failed
# Succeeded
# Succeeded with Warnings
# Level 











# Replace this in Savegroup completion
#tee "/nsr/Summaries/Savegroup`/usr/xpg4/bin/date '+%y%m%d%H%M%S'" | /usr/ucb/mail -s "sscprodeng's savegroup completion" root
#NetWorker savegroup: (alert) SAMBA-SD completed
$input[0] = <STDIN>;
#print "First before substitute=$input[0]";
($group) = $input[0] =~ /NetWorker\s+savegroup: \(\w+\) (.+)\s(?:aborted|completed)/;
#Savegroup_process.pl($group) = $input[0] =~ /NetWorker\s+savegroup: \(\w+\) (.+)\bcompleted/;
#print "First=$input[0]";
#print "Group=$group\n";
$group =~ s/\s/_/;
$i=0;
$iflag=0;
foreach $line (<STDIN>) {
  ++$i;
  if ($iflag == 0) {
     $input[$i] = $line;
     if ($line =~ /^Start time: /) {
        #print "Line=$line\n";
        #Start time:   Sun Mar 29 18:00:00 2009
        ($wday,$mon,$mday,$hr,$min,$sec,$yr) = $line =~ /^Start time:\s+(\w+)\s+(\w+)\s+(\d+)\s(\d+):(\d+):(\d+)\s+(\d+)$/; 
        $mday = sprintf("%02d",($mday));


        #print "Time=$wday,$mon,$mday,$hr,$min,$sec,$yr\n";
        $name="$yr$mon$mday\_$hr$min$sec\_$wday\_$group";
        #print "Time=$name\n";
        open(SUMMARY,">/nsr/Summaries/$name") || die "Could not open output file /nsr/Summaries/$name";
        my $return = `/usr/bin/chmod 664 /nsr/Summaries/$name`;
     
        for ($j=0;$j<=$i;$j++) {
           print SUMMARY $input[$j];
        } 
        $iflag=1;
     }
  } else {
      print SUMMARY $line;
  }  
}
# Start Production Virtual after Production Completes
#print Summary "Group=$group\n";
##if ($group =~ /Production/) {
##  $ver=$group;
##  $ver =~ s/Production//;
##  ($min,$hour,$wday) = (localtime(time))[1,2,6];
##  $min += 5;
##  if ($min > 59) {
##     $hour += 1;
##     $min -= 60;
##     # Make sure that the Production group is at least 10 minutes from next day
##  }
##  $new_start = "$hour:$min";
##
##  # Set level for the run
##  $parallelism = 150;
##  if ($wday == 0) {
##     # Its a Sunday so do a full
##     $level = "full";
##     $parallelism = 100;
##  } elsif ($wday == 1) {
##     # Its a Monday, is it before 2 (arbitrary)
##     if ($hour < 2) {
##        $level = "full";
##        $parallelism = 100;
##     }
##  } else {
##    # Intent is to have backup levels 8,7,6,5,4 so that a recover is from a full and then a differential
##    $level = 9 - $wday;
##  }
##
##  # Backups to start 5 minutes from now
##  open (NSRADMIN,">/tmp/nsradmin_production") or die "Could not open /tmp/nsradmin_production\n";
##  print NSRADMIN ". type:NSR group\;name:Production_Virtual$ver\nupdate start time:\"$new_start\"\nupdate savegrp parallelism:$parallelism\nupdate level:$level\nupdate autostart:Enabled\n";
##  close NSRADMIN;
##  $return = `/usr/sbin/nsradmin -i /tmp/nsradmin_production 2>/dev/null`;
##
##  # Wait for group to start
##  sleep(900);
##
##  # Disable
##  open (NSRADMIN,">/tmp/nsradmin_production") or die "Could not open /tmp/nsradmin_production\n";
##  print NSRADMIN ". type:NSR group\;name:Production_Virtual$ver\nupdate autostart:Disabled\n";
##  close NSRADMIN;
##  $return = `/usr/sbin/nsradmin -i /tmp/nsradmin_production 2>/dev/null`;
##}

# Add Checks for PAAS groups
# PAAS has multiple servers with the same alias
# Intent is to start PAAS2, 3, 4 in order after PAAS1 completes
# Need to transfer aliases from clients in one group to the next group
