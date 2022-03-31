#!/usr/bin/perl -w
unshift (@INC,"/home/scriptid/scripts/BACKUPS/SUBROUTINES");
require is_client_running_jobquery;

# This script processes output from RVTools (RVTools_tabvSnapshot.csv) to determine which snapshots are in place on the VMWare server.
# It then checks to see which ones were created by Networker and creates a batch file MiscRemoveSnapshot.bat
# to be run on the proxy server. 
# It starts 10 at a time (START /B) and then runs a couple to slow down the snapshot removals
(%running) = is_client_running_jobquery('sscprodeng','sscprodeng2');
open (MISC,">/home/scriptid/scripts/BACKUPS/VMware55/MiscRemoveSnapshot.bat") || die "Could not open /home/scriptid/scripts/BACKUPS/VMware55/MiscRemoveSnapshot.bat\n";
(@return) = `/usr/bin/cat /home/scriptid/scripts/BACKUPS/VMware55/RVTools_tabvSnapshot.csv`;
#$i = 1;
foreach $val (@return) {
   #      VM,Name,Description,Date / time,Filename,Size MB (vmsn),Size MB (total),Quiesced,State,Annotation,AOR,Command,Environment,System ABBR,Status,Domain,Billable,
   #      Datacenter,Cluster,Host,OS^M
   #C27SPSCNLAP2C,_NETWORKER-VADP-BACKUP_,This snapshot was created by EMC NetWorker as part of a VADP related backup on Mon Jun 13 06:57:07 2016,6/13/2016 6:57:
   chomp $val;
   my ($vm,$snapshot_name,$comment,$junk) = split(/,/,$val);
   if ($snapshot_name =~ /_NETWORKER-VADP-BACKUP_/) {
      $vm =~ s/\:.*$//;
      #$i++;
      if (defined $running{lc($vm)}) {
         #print "**********Running $running{$vm}\n";
         next;
      }
      $misc_delete{$vm} = 1;
   } else {
      #print "$i Someone else has snapshot for $val, **************$snapshot_name***************\n\n";
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
   print MISC "$prefix testsnapshot.exe -H vmware55-nola  -u cdc\\vadp -p 1qaz2wsx\!QAZ\@WSX -l vm-name -k $val -c delete -n _NETWORKER-VADP-BACKUP_\r\n";
}
print MISC "exit\n";
close MISC;
$return = `/bin/chmod 755 /home/scriptid/scripts/BACKUPS/VMware55/MiscRemoveSnapshot.bat`;
