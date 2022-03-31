#!/usr/bin/perl -w
unshift (@INC,"/home/scriptid/scripts/BACKUPS/SUBROUTINES");
require append_group;
require build_output_record;
require create_group_name_from_esx_host_name;
require check_backups_on_other_server;
require handle_nsradmin_line_continuations;
require is_client_running_jobquery;
require pinger;
require read_tabvInfo_old;
require remove_clients_from_group;
require resolv_name;
require start_group;
require stop_group;
require show_group;
require testport;
require update_clients_group;

# Purpose of utility is to display the ESX Hostname for each client in a speacific group
#
#------------------------------------------------------------------------------------------------------------
#
$BACKUPSERVER    = 'sscprodeng';
$ALTERNATESERVER = 'sscprodeng2'; 		# If blank then only uses BACKUPSERVER
(@servers) = ($BACKUPSERVER,$ALTERNATESERVER);


#################################################################################################################################
# Set up rap logs to track changes
#################################################################################################################################
$date = `/usr/bin/date '+%y%m%d%H%M%S'`;
chomp $date;
open (RAP,">>/home/scriptid/scripts/BACKUPS/RAP/WESXH_RAP_$date.log") or die "Could not open /home/scriptid/scripts/BACKUPS/RAP/WESXH_RAP_$date.log\n";

#################################################################################################################################
# Need to compute totalsize once and only want to compute it on the server on which it is scheduled, it could have been moved

# Don't need to include on the server machines that are not scheduled, that are Decom'd, that are not VADP
# Nothing this script does changes the above

#################################################################################################################################
# Get info from RvTools
# RvTools has all the x86 Virtuals Linux, Windows, VADP backups
# All indexed by lowercase client
print "\nBefore Read of Virtual Center Information\n";
read_tabvInfo_old();
print "After Read of Virtual Center Information\n\n";
#################################################################################################################################


foreach $server (@servers) {
  # Build a list of the max size for each server
  (@return) = `/usr/sbin/mminfo -s $server -xc, -r 'client,group' -q 'level=full,savetime>last month' | /usr/bin/sort | /usr/bin/uniq`;
  #print MAIL "	Building list of clients and their groups on $server\n";
  foreach $record (@return) {
     next if $record =~ /client/;
     chomp $record;
     ($client,$group) = split(/,/,$record);
     $client = lc $client;
     $groups{$client} = $group;
  }
}

#foreach $val (keys %groups) {
#  print "Client:$val, ESX_HOST=$Host{$val}\n";
#}
TOP:
print "Enter networker group name to search or all: ";
$search = <STDIN>;
chomp $search;
foreach $val (sort keys %DNS_Name) {
   $client = $DNS_Name{$val};
   $client =~ s/\.\S+$//;
   $client = lc $client;
   next if $client =~ /^\s*$/;
   next if $client =~ /^\d/;
   $dns = resolv_name($val);
   if ($dns =~ /Not in DNS/) {
      #print "WARN: VM $client not in DNS\n";
   } else {
      $hostname = reverse_lookup($Host{$val},$Host{$val});
      #if ($client =~ /mfom/) {
      #   print "Client=$client, Group=$groups{$client}, Host=$hostname\n";
      #}
      if (defined $groups{$client}) {
         if ($groups{$client} =~ /$search/ || (lc  $search =~ /^all$/))  {
            print "Client=$client, Group=$groups{$client}, Host=$hostname\n";
         }
      } else {
           #print "Networker Group not defined for $client\n";
      }
   }
}



sub reverse_lookup {
    my ($check,$key) = @_;
    my $IP = $check;
    $name = "No DNS Name";
    if ($IP !~ /\./) {
       print MAIL "WARN: No reverse lookup for $key\n";
    } else {
       use Socket;
       $iaddr = inet_aton("$IP");
       $name = gethostbyaddr($iaddr, AF_INET);
       if ( !defined $name ) {
          $return = build_output_record(-80,$output,$check,18,0,-1,-1 ,'',1,18);
          $return = build_output_record(0,$output,'ERROR',10,0,1,1 ,'',19,29);
          $return = build_output_record(0,$output,"No reverse lookup for $key",51,0,0,0 ,'',30,80);
          print MAIL "$return\n";
          $name = "No DNS Name";
       }
    }
    return $name;
}

