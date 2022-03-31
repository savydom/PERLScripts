#!/usr/bin/perl -w
# This script processes output from RVTools (RVTools_tabvSnapshot.csv) to determine which snapshots are in place on the VMWare server.
# It then checks to see which ones were created by Networker and creates a batch file MiscRemoveSnapshot.bat
# to be run on the proxy server. 
# It starts 10 at a time (START /B) and then runs a couple to slow down the snapshot removals
is_client_running_jobquery('sscprodeng','sscprodeng2');
open (MISC,">/home/scriptid/scripts/BACKUPS/RVTools3.8/MiscRemoveSnapshot.bat") || die "Could not open /home/preed//MiscRemoveSnapshot.bat\n";
(@return) = `/usr/bin/cat /home/scriptid/scripts/BACKUPS/RVTools3.8/RVTools_tabvSnapshot.csv`;
foreach $val (@return) {
   #      VM,Name,Description,Date / time,Filename,Size MB (vmsn),Size MB (total),Quiesced,State,Annotation,AOR,Command,Environment,System ABBR,Status,Domain,Billable,
   #      Datacenter,Cluster,Host,OS^M
   #C27SPSCNLAP2C,_NETWORKER-VADP-BACKUP_,This snapshot was created by EMC NetWorker as part of a VADP related backup on Mon Jun 13 06:57:07 2016,6/13/2016 6:57:
   chomp $val;
   my ($vm,$snapshot_name,$comment,$junk) = split(/,/,$val);
   if ($snapshot_name =~ /_NETWORKER-VADP-BACKUP_/) {
      $vm =~ s/\:.*$//;
      #print "VM=$vm, Snapshot Name:$snapshot_name, Comment=$comment\n";
      #print MISC "testsnapshot.exe -H vmware-nola -u cdc\\vadp -p 1qaz2wsx\!QAZ\@WSX -l vm-name -k $vm -c delete -n _NETWORKER-VADP-BACKUP_\n";
      print "VM=$vm\n";
      if (defined $running{$vm}) {
         print "Running $running{$vm}\n";
         next;
      }
      #print "VM=$vm\n";
      $misc_delete{$vm} = 1;
   }
}
$count = 0;
foreach $val (sort keys %misc_delete) {
   ++$count;
   if ($count < 8) {
      $prefix = "START /B";
   } elsif ($count < 9) {
      $prefix = "";
   } else {
      $count = 0;
   }
   print MISC "$prefix testsnapshot.exe -H vmware-nola -u cdc\\vadp -p 1qaz2wsx\!QAZ\@WSX -l vm-name -k $val -c delete -n _NETWORKER-VADP-BACKUP_\r\n";
}
print MISC "exit\n";
close MISC;

sub is_client_running_jobquery {
   ($networker,$alternate) = @_;
   # Determine if the client is still running from other groups
   # Need to save the time also since the process returns multiple entries
   # Active means that the job is in  "Waiting to Run" and writing meta data or waiting for Disaster recovery
   # Queued means that the job is in  "Waiting to Run"  and is not yet running
   # Session Active means the job is writing
   print "Determining running sessions\n";

   $nsrpass = ". type: save job\\; job state: SESSION ACTIVE'\n'show NW Client name/id'\n'print";
   foreach $server ($networker,$alternate) {
      (@return) = `/usr/bin/echo $nsrpass | /usr/sbin/jobquery -s $server -i - 2>&1`;
      foreach $val (@return) {
         next if $val=~/Current query set/;
         next if $val=~/No resources found for query/;
         next if $val=~/type: save job/;
         next if $val=~/job state: SESSION ACTIVE/;
         next if $val=~/^\s*$/;
         $val =~ s/^\s+NW Client name\/id: //;
         $val =~ s/\;//;
         $val = lc $val;
         $running{$val} = 1;
         print "Session Active=$val";
      }
   }

   $nsrpass = ". type: save job\\; job state: ACTIVE'\n'show NW Client name/id'\n'print";
   foreach $server ($networker,$alternate) {
      (@return) = `/usr/bin/echo $nsrpass | /usr/sbin/jobquery -s $server -i - 2>&1`;
      foreach $val (@return) {
         next if $val=~/Current query set/;
         next if $val=~/No resources found for query/;
         next if $val=~/type: save job/;
         next if $val=~/job state: ACTIVE/;
         next if $val=~/^\s*$/;
         $val =~ s/^\s+NW Client name\/id: //;
         $val =~ s/\;//;
         $val = lc $val;
         $running{$val} = 1;
         print "Active=$val";
      }
   }

   $nsrpass = ". type: save job\\; job state: QUEUED'\n'show NW Client name/id'\n'print";
   foreach $server ($networker,$alternate) {
      (@return) = `/usr/bin/echo $nsrpass | /usr/sbin/jobquery -s $server -i - 2>&1`;
      foreach $val (@return) {
         next if $val=~/Current query set/;
         next if $val=~/No resources found for query/;
         next if $val=~/type: save job/;
         next if $val=~/job state: QUEUED/;
         next if $val=~/^\s*$/;
         $val =~ s/^\s+NW Client name\/id: //;
         $val =~ s/\;//;
         $val = lc $val;
         $running{$val} = 1;
         print "QUEUED=$val";
      }
   }
}

