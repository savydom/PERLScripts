#!/usr/bin/perl -w
# This is used to determine if file system index backups have been created
# The intent is to not only make the filesystems contiguous but also have all client's filesystems contiguous
# Peter Reed (Aventure)
# 07 13, 2017
# 1.1.0
#
# Assumptions:
#	1. The real problems are that Cloning and staging write out data
#		to secondary media by processing savesets (file systems on
#		a client). The challenge is to eliminate contention for a
#		specific tape when multiple cloning streams are running 
#		concurrently.  What happens is that cloning stream 1 is
#		processing saveset 1234 on tape 456.  Cloning stream 2
#		is processing saveset 8910 on tape 1112 but part of saveset
#		8910 is on tape 456 which is still being used by stream 1.
#		Stream 2 has to wait for stream 1 to finish.
#                
#		This is not  problem for AFTD devices
#
#	2. For performance reasons, it is better to have virtual tapes being
#		read from both jukeboxes. (This coulld have one stream finish early).
#	3. Virtual tapes should be sequecnced oldest to newest with
#		the first stream processing the first '# of tapes/number of streams'
#		tapes.  Consecutive streams read the next '# of tapes/number of streams'
#		tapes.  The hope is that this will minimize contension for tapes
#	4. Don't know optimal streams for load on AFTD or 
#	5. The program backs up all savesets not already written to tape

$number_of_streams=3;

# week_day -> $wday begins with Sunday (0) till Saturday (6)
use Time::Local;

# Get the current time
$seconds_from_1970 = time;
# Determine real world units
($sec,$min,$hour,$mon,$yr,$yday) = (localtime($seconds_from_1970))[0,1,2,4,5,7];
++$mon;
$yr = $yr+1900;
#$finish="\'$mon/$mday/$yr $hour:$min:$sec\'";

# Open the log file
$datestamp = "$yr$yday$hour$min$sec";
$logfile="/home/scriptid/scripts/BACKUPS/CLONING/clone_log_$datestamp";
open (LOG,">$logfile") or die "Could not open logfile $logfile\n";


print LOG "Begin cloning $hour:$min:$sec Year:$yr Julian Date:$yday\n";
# Check to see is cloning is already running
#if (`/usr/bin/pgrep -f  "AFTD"`) {
#   print LOG "Cloning already running\n";
#   exit;
#}

# Determine the tapes that were used for the weekend full backups
 print "Level";
(@VOLRETENT) = `/usr/sbin/mminfo -o cn -av -xc, -r 'volume,client,name,ssid(53),savetime(20)' -q 'copies=1,pool=AFTD_POOL,savetime>10 days ago' 2>&1`;
(@VOLRETENT2) = `/usr/sbin/mminfo -o cn -av -xc, -r 'volume,client,name,ssid(53),savetime(20)' -q 'copies=1,pool=AFTD2_POOL,savetime>10 days ago' 2>&1`;
push (@VOLRETENT,@VOLRETENT2);
open (CLONE,">/home/scriptid/scripts/BACKUPS/CLONING/clone_list_$datestamp") or die "Could not open clone_list file\n";
foreach $val (@VOLRETENT) {
   if ($val =~ "[Vv]olume") {
      next;
   } elsif ($val =~ /expired/) {
      next;
   } elsif ($val =~ /no matches found for the query/) {
      next;
   }
   chop $val;
   my ($volume,$client,$filesystem,$ssid,$savetime) = split(/,/,$val);
   if ( defined $client_ssids{$client} ) {
      $client_ssids{$client} = "$client_ssids{$client}\:$ssid";
   } else {
      $client_ssids{$client} = $ssid;
   }
}
foreach $client (sort keys %client_ssids) {
   print CLONE "$client:$client_ssids{$client}\n";
}
$i=0;
while ($i<$number_of_streams) {
    ++$i;
    $clone_name="CLONE" . $i;
    close  $clone_name; 
    print "Starting clone stream $i\n";
    print LOG "/n/nBefore entering process $datestamp $i\n";
    my $ret = system("/home/scriptid/scripts/BACKUPS/process_client_AFTD_clone.pl $datestamp $i &");
    sleep 5;
}
close LOG;
