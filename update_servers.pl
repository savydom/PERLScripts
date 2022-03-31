#!/usr/bin/perl -w
# This script is used to add entries for the sscprodeng2 server toi local host files
# It also replaces the /nsr/res/servers file with a new one
$hostname = `/bin/hostname`;
print "\nBegin networker update for hostname $hostname";
$return = `/bin/grep sscprodeng2 /etc/hosts`;
if ($return) {
   print "\t***** SScprodeng2 already added to server\n";
   exit;
}
$return = `/bin/cat /home/scriptid/scripts/BACKUPS/add_sscprodeng2.txt >> /etc/hosts`;
if ($return) {
   print "\t*****Problem updating local hosts file, existing\n";
   exit;
}
$return = `/etc/init.d/networker stop`;
if ($return) {
   print "\t***** Problems stopping networker\n\t$return";
   print "\t exiting\n";
   exit;
} else {
   $return = `/bin/cp /home/scriptid/scripts/BACKUPS/new_networker_servers_file.txt /nsr/res/servers`;
   if ($return) {
      print "\t***** Problems overwriting /nsr/res/servers file\n\t$return";
      print "\t exiting\n";
      exit;
   } else {
      print "\tCompleted overwrite of /nsr/res/servers file\n";
   }
}
$return = `/etc/init.d/networker start`;
if ($return) {
   print "\t***** Problems starting networker\n\t$return";
   print "\t exiting\n";
   exit;
} else {
   print "\tNetworker started successfully\n";
}
