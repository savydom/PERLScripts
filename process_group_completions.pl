#!/usr/bin/perl -w 
# The /nsar/Summaries directories have files based on the start time of the group
# We want to process all files from yesterday at 17:00
# Create the start time to look for Ex: yesterday 2017Mar10 and today 2017Mar11
# Do ls -1 2017Mar10* and ls -1 2017Mar11 to build preliminary lists
# Eliminate files before yesterday at 17:00
use Time::Local;
$test='2017Mar10_000900_Fri_VADP-Devpriv-Ch2-910-B2';
%convert_month_to_txt = (0,Jan,1,Feb,2,Mar,3,Apr,4,May,5,Jun,6,Jul,7,Aug,8,Sep,9,Oct,10,Nov,11,Dec);
%convert_txt_to_month = (Jan,0,Feb,1,Mar,2,Apr,3,May,4,Jun,5,Jul,6,Aug,7,Sep,8,Oct,9,Nov,10,Dec,11);

# Get the current time
$seconds_from_1970 = time;
$yesterday = $seconds_from_1970 - 24*3600;
($mday,$mon,$yr) = (localtime($yesterday))[3,4,5];
$yr+=1900;
$mday = sprintf("%02d",($mday));
$test = "$yr$convert_month_to_txt{$mon}$mday";
(@return) = `/usr/bin/ls -1 /nsr/Summaries/$test*`;
#============================================================================
# Process the list of files from starting Yesterday
#============================================================================
# Get the list of files created yesterday 
foreach $val (@return) {
   chomp $val;
   #$val =~ s:/nsr/Summaries/::;
   ($year,$mon,$day,$hr,$min,$sec,$wday,$group) = ($val =~ /(\d\d\d\d)(\D\D\D)(\d\d)\_(\d\d)(\d\d)(\d\d)\_(\D\D\D)\_(.*)$/);
   if ($hr > 16) {
      push (@run,$val);
   }
}
# Get the list of files from today
($mday,$mon,$yr) = (localtime($seconds_from_1970))[3,4,5];
$yr+=1900;
$mday = sprintf("%02d",($mday));
$test = "$yr$convert_month_to_txt{$mon}$mday";
(@return) = `/usr/bin/ls -1 /nsr/Summaries/$test*`;
foreach $val (@return) {
   chomp $val;
   $val =~ s:/nsr/Summaries/::;
   push (@run,$val);
}

#============================================================================
# @run has the list of files from 16:00 yesterday until now
#============================================================================
foreach $val (@run) {
   ($yr,$mon,$day,$hr,$min,$sec,$wday,$group) = ($val =~ /(\d\d\d\d)(\D\D\D)(\d\d)\_(\d\d)(\d\d)(\d\d)\_(\D\D\D)\_(.*)$/);
   next if $group =~ /Auditlog/;
   next if $group =~ /^\s*$/;
   next if $group =~ /INDEX/;
   $month = $convert_txt_to_month{$mon};
   $year = $yr - 1900;
   $start_secs = timelocal($sec,$min,$hr,$day,$month,$year);
   # Should AFTD be excluded
   next if $group =~ /AFTD Test/;
   # This will be run on each host so lose the ssh
   #(@failed)    = `/usr/bin/ssh -q $user\@$server "/usr/xpg4/bin/grep \'^Failed\'  \'$savegroup_name\'"`;
   #(@failed)    = `/usr/bin/grep \'^Failed\'  \'$savegroup_name\'`;
   # Are we taking care of multiple lines
   #============================================================================
   # Determine the servers that failed 
   #============================================================================
   print "Filename /usr/bin/grep \'^Failed:\'  *****/nsr/Sumaries/$val*****\n";
   (@failed)    = `/usr/bin/grep \'^Failed:\'  /nsr/Summaries/$val`;
   # Have to keep track of all succeeded and failed to test at the end, succeeded group could process before failed group
   foreach $fff (@failed) {
      chomp $fff;
      $temp = $fff;
      $temp =~ s/^Failed.*\: //;
      (@temp_failed) = split(/,\s*/,$temp);
      #print "Number of failed servers = $#temp_failed for group $group\n";
      # Break down returned values into individual servers
      foreach $ggg (@temp_failed) {
         $ggg = lc $ggg;
         if (defined $failed_test{$ggg}) {
            #print "Server Failed=$ggg, Start Seconds=$start_secs, Current Value=$failed_test{$ggg}, $group----\n";
            # The value has already been set so check to see if it should be updated, is it later
            if ($start_secs > $failed_test{$ggg}) {$failed_test{$ggg} = $start_secs};
         } else {
            $failed_test{$ggg} = $start_secs;
            # Keep track of what group the client last ran from
            $failed_test_group{$ggg} = $group;
         }
      }
   }
   foreach $vv (sort keys %failed_test) {
      print "Failed Server $vv, Failed Time $failed_test{$vv}\n";
   }

   #============================================================================
   # Determine the servers that succeeded 
   #============================================================================
   (@Succeeded)    = `/usr/bin/grep \'^Succeeded:\'  /nsr/Summaries/$val`;
   foreach $fff (@Succeeded) {
      chomp $fff;
      $temp = $fff;
      # Will process succeeded with warnings separately
      #$temp =~ s/^Succeeded.*\: //;
      $temp =~ s/^Succeeded: //;
      (@temp_succeeded) = split(/,\s*/,$temp);
      foreach $ggg (@temp_succeeded) {
         $ggg = lc $ggg;
         if (defined $succeededww_test{$ggg}) {
            #print "Server Succeeded=$ggg, Start Seconds=$start_secs, Current Value=$succeeded_test{$ggg}, $group-----\n";
            # The value has already been set so check to see if it should be updated
            if ($start_secs > $succeeded_test{$ggg}) {$succeeded_test{$ggg} = $start_secs};
         } else {
            $succeeded_test{$ggg} = $start_secs;
         }
      }
   }
   foreach $vv (sort keys %succeeded_test) {
      print "Succeeded Server $vv, Succeeded Time $succeeded_test{$vv}\n";
   }

   #============================================================================
   # Determine the servers that succeeded with warnings maybe used in future
   #============================================================================
   (@Succeeded_with_warnings)    = `/usr/bin/grep \'^Succeeded with warning(s):\'  /nsr/Summaries/$val`;
   foreach $fff (@Succeeded_with_warnings) {
      chomp $fff;
      $temp = $fff;
      # Will process succeeded with warnings 
      #$temp =~ s/^Succeeded.*\: //;
      $temp =~ s/^Succeeded with warnings\(s\): //;
      (@temp_succeeded) = split(/,\s*/,$temp);
      foreach $ggg (@temp_succeeded) {
         $ggg = lc $ggg;
         if (defined $succeededww_test{$ggg}) {
            #print "Server Succeeded=$ggg, Start Seconds=$start_secs, Current Value=$succeeded_test{$ggg}, $group-----\n";
            # The value has already been set so check to see if it should be updated
            if ($start_secs > $succeededww_test{$ggg}) {$succeededww_test{$ggg} = $start_secs};
         } else {
            $succeeded_test{$ggg} = $start_secs;
         }
      }
   }
#   foreach $vv (sort keys %succeededww_test) {
#      print "Succeededww Server $vv, Succeeded Time $succeededww_test{$vv}\n";
#   }

#     # Do test to generate failed_servers array
#     # Really only concerned with the failures for loop on failed servers
#     foreach $fff (sort keys %failed_test) {
#        if (  (defined $succeeded_test{$fff}))  {print "Succeeded $succeeded_test{$fff}, Failed $failed_test{$fff}"};
#        if (  (defined $succeeded_test{$fff} )  && ($succeeded_test{$fff} > $failed_test{$fff}) ) {next};
#        $ffailed{$fff} =$failed_test_group{$fff};
}

