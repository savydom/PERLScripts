#!/usr/bin/perl -w
# This utility is used to find the unremediated backups since 16:00 yesterday.
# This is used to create an automated rerun at 4:00 in the morning
# passing print to the script with just report and not update the group

use Time::Local;
%convert_month_to_index = (Jan,0,Feb,1,Mar,2,Apr,3,May,4,Jun,5,Jul,6,Aug,7,Sep,8,Oct,9,Nov,10,Dec,11);
        #%convert_month_to_txt = (0,Jan,1,Feb,2,Mar,3,Apr,4,May,5,Jun,6,Jul,7,Aug,8,Sep,9,Oct,10,Nov,11,Dec);
        #%convert_month = (Jan,0,Feb,1,Mar,2,Apr,3,May,4,Jun,5,Jul,6,Aug,7,Sep,8,Oct,9,Nov,10,Dec,11);
if (defined $ARGV[0] ) {
   $server =  $ARGV[0];
} else {
   $server = `/usr/bin/hostname`;
   chomp $server;
}


$date = `/usr/bin/date '+%y%m%d%H%M%S'`;
chomp $date;
#$FAILADDRS='peter.reed.ctr\@navy.mil jeffrey.l.rodriguez.ctr\@navy.mil cody.p.crawford.ctr\@navy.mil';
#$FAILADDRS='peter.reed.ctr\@navy.mil';
#$filename = "/home/scriptid/scripts/BACKUPS/daily_reports/$server\_$date";
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
if ($last_wednesday > 10) {$last_wednesday -= 7};
# Start Seconds is based on Wednesday @ 16:00
$start_seconds_last_wednesday = $today_16 -$last_wednesday*24*3600;

# The find command will locate files based on the date the runs completed not the time they were started
$last_tuesday = $last_wednesday +1;

#/backup/nsr/Summaries/2017May16_001200_Tue_VADP-Prodspec-Ch1-620-B9
#/backup/nsr/Summaries/2017May16_003300_Tue_VADP-Devpriv-Ch2-910-B3
#/backup/nsr/Summaries/2017May15_184800_Mon_VADP-Transqa-Ch1-610-B4
# Get a list of all the files created from last Tuesday, Because of the sort as soon as date is past end date can stop loop
(@savegroups) = `$SUDO /usr/bin/find /backup/nsr/Summaries -type f -mtime -$last_tuesday -exec /usr/bin/ls -1 \{\} \\\; | /usr/bin/sort`;
$SUCCEEDED_WITH_WARNINGS=$SUCCEEDED=$FAILED=$max_clients=0;
for ($i=0; $i<7; $i++) {
   $start_seconds = $start_seconds_last_wednesday+24*3600*$i;
   $end_seconds   = $start_seconds + 3600*24;
   
   # Build a list of files to process
   undef %warning;
   undef %test;
   foreach $val (@savegroups) {
      next if ($val =~ /INDEX/);
      chomp $val;
      ($year,$month,$mday,$hr,$min,$sec) = ($val =~ /\/backup\/nsr\/Summaries\/(\d\d\d\d)(\D\D\D)(\d\d)\_(\d\d)(\d\d)(\d\d)/);
      #print "$year,$month,$mday,$hr,$min,$sec  ";
      $year -= 1900;
      $month = $convert_month_to_index{$month};
      $file_time_secs = timelocal($sec,$min,$hr,$mday,$month,$year);
      #print "File time Seconds:$file_time_secs, $start_seconds, $end_seconds\n";
      next if $file_time_secs < $start_seconds;
      last if $file_time_secs > $end_seconds;
      #print "Processing $val\n";
      (@return) = `/usr/bin/cat $val\"`;
      $failed=$succeeded_with_warnings=$succeeded=$start_time=$end_time=' ';
      foreach $line (@return) {
        chomp $line;
        if ($line =~ /^Failed:/) {
           $failed = $line;
           $failed =~ s/Failed: //;
        } elsif ($line =~ /^Succeeded with warning\(s\):/) {
           $succeeded_with_warnings = $line;
           $succeeded_with_warnings =~ s/Succeeded with warning\(s\): //;
           #print "/n/nSucceeded_with_warning*****=$succeeded_with_warnings\n";
        } elsif ($line =~ /^Succeeded:/) {
           $succeeded = $line;
           $succeeded =~ s/Succeeded: //;
        } elsif ($line =~ /^Start time:/) {
           $start_time = $line;
           $start_time =~ s/Start time: //;
        } elsif ($line =~ /^End time:/) {
           $end_time  = $line;
           $end_time  =~ s/End time:\s+//;
           #End time:     Mon May 15 21:56:00 2017
           ($wday,$mon,$mday,$hr,$min,$sec,$year) = ($end_time =~ /(\D\D\D)\s(\D\D\D)\s(\d\d)\s(\d\d)\:(\d\d)\:(\d\d)\s(\d\d\d\d)/);
           $mon = $convert_month_to_index{$mon};
           $year -= 1900;
           $status_time_secs = timelocal($sec,$min,$hr,$mday,$mon,$year);
        } else {

        }
      }
   
      (@succeeded)              = split(/, /,$succeeded);
      (@fails)                  = split(/, /,$failed);
      (@succeeded_with_warning) = split(/, /,$succeeded_with_warnings);
      #print "Succeeded=@succeeded\n";
      #print "Fails=@fails\n";
      #print "Succeeded_with_warning*****=@succeeded_with_warning\n";

      foreach $val1 (@succeeded) {
         chomp $val1;
         next if $val1 =~ /^\s*$/;
         if (defined $test{$val1}) {
            if ( $status_time_secs > $test{$val1} ) {
               # Completed came after failed or rerun at a later time
               $test{$val1} = $status_time_secs;
               #print "In defined succeeded $val1, $test{$val1}\n";
            }
         } else {
            $test{$val1} = $status_time_secs;
            #print "In undefined succeeded $val1, $test{$val1}\n";
         }
         #print "Succeeded=$val1\n";
      }
      foreach $val1 (@succeeded_with_warning) {
         chomp $val1;
         next if $val1 =~ /^\s*$/;
         if ( defined $test{$val1} ) {
            if ( $status_time_secs > $test{$val1} ) {
               # Completed came after failed or rerun at a later time
               $test{$val1} = $status_time_secs;
               $warning{$val1} = $status_time_secs;
               #print "warning=$val1, $warning{$val1}\n";
            }
         } else {
            $test{$val1} = $status_time_secs;
            $warning{$val1} = $status_time_secs;
            #print "warning=$val1, $warning{$val1}\n";
         }
         #print "Succeeded with warning=$val1\n";

      }
      foreach $val1 (@fails) {
         chomp $val1;
         next if $val1 =~ /^\s*$/;
         if ( defined $test{$val1} ) {
            if ( $status_time_secs > abs($test{$val1}) ) {
               # Failed came after succeeded or rerun at a later time
               $test{$val1} = - $status_time_secs;
               #print "warning=$val1, undef\n";
               undef $warning{$val1};
            }
         } else {
            $test{$val1} = - $status_time_secs;
            #print "warning=$val1, undef\n";
            undef $warning{$val1};
         }
         #print "Failed=$val1\n";
      }
   }
   $counter = keys %test;
   #print "Daily Number of Clients=$counter\n";
   if ($counter > $max_clients) {$max_clients=$counter};



# ****************************** Process Daily Totals ****************************************

   # Check to see which clients are scheduled
   #my $run = is_client_scheduled($server);

   foreach $val (sort keys %test) {
      #print "Keys=$val\n";
      #if ( defined $scheduled_backup{$val} ) {
         if ($test{$val} < 0) {
            $FAILED += 1;
         } else {
            if (defined $warning{$val}) {
               #print "SUCCEEDED_WITH_WARNINGS=$val, $warning{$val}\n";
               $SUCCEEDED_WITH_WARNINGS += 1;
            } else {
               $SUCCEEDED += 1;
            }
         }
      #}
   }

# End of day loop
}
$TOTAL = $SUCCEEDED+$SUCCEEDED_WITH_WARNINGS+$FAILED;
if (defined $ARGV[1]) {
   print "$max_clients,$TOTAL,$SUCCEEDED,$SUCCEEDED_WITH_WARNINGS,$FAILED\n";
} else {
   print " S E R V E R = $server\n";
   print " Maximum Number of Clients: $max_clients\n";
   print "      Total CLient Backups:  $TOTAL\n";
   $percent = $SUCCEEDED/$TOTAL*100;
   print "                 Succeeded: $SUCCEEDED, $percent\n";
   $percent = $SUCCEEDED_WITH_WARNINGS/$TOTAL*100;
   print "   Succeeded with Warnings: $SUCCEEDED_WITH_WARNINGS, $percent\n";
   $percent = $FAILED/$TOTAL*100;
   print "                    Failed: $FAILED, $percent\n";
}

sub is_client_scheduled {
   $nsrpass = ". type:NSR client'\n'show name\\;scheduled backup'\n'print";
   (@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin  -i -`;
   # Client name  is mixed case so lower case the names
   foreach $val (@return) {
      chomp $val;
      $val =~ s/\;//;
      next if $val =~ /^\s*$/;
      if ($val =~ /name:/) {
         $val =~ s/\s*name: //;
         #$name = lc($val);
         $name = $val;
      }  elsif ($val =~ /scheduled backup/) {
         $val =~ s/\s*scheduled backup: //;
         $scheduled_backup{$name} = $val;
      }

   }
   return %scheduled_backup;
}
