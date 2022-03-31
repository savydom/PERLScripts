#!/usr/bin/perl -w
$plan = @_;

# Set up email
$MAILADDRS='peter.reed.ctr\@navy.mil jeffrey.l.rodriguez.ctr\@navy.mil ashley.nguyen.ctr\@navy.mil blake.arcement.ctr\@navy.mil cody.p.crawford.ctr\@navy.mil';
#$MAILADDRS='peter.reed.ctr\@navy.mil';
$date = `/usr/bin/date '+%y%m%d%H%M%S'`;
chomp $date;
$filename = "/home/scriptid/scripts/BACKUPS/REBALANCE/rebalance\_$date";
open(MAIL,">$filename") or die "Can't open file $filename\n";
print MAIL "/usr/bin/mailx -s 'Rebalance VADP Groups on both servers ($date)' $MAILADDRS <<ENDMAIL\n";

# If plan is set to 'plan' then clients will not be moved the changes will just be documented
if (-t STDIN && -t STDOUT) {
   # We are running from a terminal and not batch
   if ( lc($plan) =~ /plan/) {
      print "Plan=$plan\n";
    } else {
      print "Do you want to just see the plan of what will be done enter 'plan': ";
      $plan = lc(<STDIN>);
      chomp $plan;
   }
}
if ($plan =~ /plan/) {
   print MAIL "\n\n**************************************************************\n";
   print MAIL    " * No changes will be made.  This is the plan for the changes *\n";
   print MAIL     "**************************************************************\n\n";
}
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

# Purpose of utility is to find new clients and to move Windows clients into groups based
# on the blade that they are loaded. We will only move clients that are in the VADP groups.
# If VMware clients are larger than "600GB' they will be backed up under a LARGE group.
# If VMware clients are Linux they go into a normal group.  
# The following tags are in the comment field in NetWorker.
#	A:; - AFTD
#	D:; - decom
#	L:; - Linux
#	U:; - UNIX
#	V:; - Open VMS
#	W:; - Windows
#	P:; - Production
#	I:; - Ignore
#	N:; - No Automatic Reruns
# Clients are added to backups if the are up, in DNS, and responding on port 7937
# Clients are moved if they are in NORMAL, LARGE,  or VADP groups.
# Clients can also be moved based on the time that they take to backup.
# NORMAL groups might not be required, thinking they should be merged into the VADP groups helping 
# reduce the load on the VMware infrastructure. Needs to be looked at.
# First pass tuning will be to connect all clients in the same group based on their blade.
# Parallelism needs to be determined to minimize snapshot load (we have memory size and disk space size
# and even the LUNs).
# Handle groups as a client update
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
open (RAP,">>/home/scriptid/scripts/BACKUPS/RAP/VADP_RAP_$date.log") or die "Could not open /home/scriptid/scripts/BACKUPS/RAP/VADP_RAP_$date.log\n"; 

#################################################################################################################################
# Need to compute totalsize once and only want to compute it on the server on which it is scheduled, it could have been moved

# Don't need to include on the server machines that are not scheduled, that are Decom'd, that are not VADP
# Nothing this script does changes the above
print MAIL "\n\n*** R e b a l a n c e  V M w a r e  C l i e n t s  t o  G r o u p s (Version 3.2.6.0) ***\n\n";
print MAIL "Check /home/scriptid/scripts/BACKUPS/RAP/VADP_RAP_$date.log for a list of all clients and why they were excluded...\n\n";
print MAIL "Building list of VADP servers in backups\n";
foreach $server (@servers) {
    $total_server{$server} = 0;
    print MAIL "\tBuilding server list for $server\n";
    $nsrpass = ". type:NSR client'\n'show name\\;scheduled backup\\;group\\;backup command\\;action'\n'print";
    (@return) = handle_nsradmin_line_continuations($server,$nsrpass);	# Get list back from nsradmin but concatenate long lines like group and comment
    print MAIL "\t\tNumber of records returned = $#return\n";
    for ($i=0; $i<=$#return; $i++) {
       next if $return[$i] =~ /^\s*$/;		# Skip blank lines
       if ($return[$i] =~ /name/) {
          if ($return[$i+1] =~ /Disabled/) {	# Scheduled Backup
             print RAP "INFO: Skipped client $return[$i] because it is disabled\n";
             $i+=3;
             next;
          }
          if ($return[$i+2] =~ /DECOM/) {		# Group
             print RAP "INFO: Skipped client $return[$i] because it is in the DECOMgroup\n";
             $i+=3;
             next;
          }
          if ($return[$i+2] =~ /MIDNIGHT/) {		# Group
             print RAP "INFO: Skipped client $return[$i] because it is in the MIDNIGHT Group\n";
             $i+=3;
             next;
          }
          if ($return[$i+2] =~ /BigandSlow/) {		# Group
             print RAP "INFO: Skipped client $return[$i] because it is in the BigandSlow Group\n";
             $i+=3;
             next;
          }
          if ($return[$i+2] =~ /Nuclear/) {		# Group
             print RAP "INFO: Skipped client $return[$i] because it is in  a Nuclear Group\n";
             $i+=3;
             next;
          }
          if ($return[$i+2] =~ /PROBLEMS/) {		# Group
             print RAP "INFO: Skipped client $return[$i] because it is in the PROBLEMS Group\n";
             $i+=3;
             next;
          }

          if ($return[$i+2] !~ /VADP/) {		# Only process VADP Groups
             print RAP "INFO: Skipped client $return[$i] because it's not VADP\n";
             if ($return[$i+2] =~ /group: \;/) {		# Group
                print RAP "WARN: client $return[$i] is in  NO  Group on $server and won't be automatically moved\n";
                print MAIL "WARN: client $return[$i] is in  NO  Group on $server and won't be automatically moved\n";
                print "WARN: client $return[$i] is in  NO  Group on $server and won't be automatically moved\n";
             }
             if ($return[$i+2] =~ /group: INDEX\;/) {		# Group
                print RAP "WARN: client $return[$i] is only in group INDEX on $server and won't be automatically moved\n";
                print MAIL "WARN: client $return[$i] is only in group INDEX on $server and won't be automatically moved\n";
                print "WARN: client $return[$i] is only in group INDEX on $server and won't be automatically moved\n";
             }
             $i+=3;
             next;
          }
          if ($return[$i+3] !~ /nsrvadp_save/) {	# backup command
             print RAP "INFO: Skipped client $return[$i] because it doesn't have nsrvadp_save set\n";
             $i+=3;
             next;
          }

          # Save this info 
          ($client) = ($return[$i] =~ /^.*name: (.*)\;$/);
          $client = lc($client);		# Lower case clients
          if (defined $which_server{$client}) {
             print MAIL "ERROR: $client enabled on both backup servers\n";
             $i+=4;
          } else {
             $which_server{$client} = $server;
             $total_server{$server} +=1;
             $i+=2;
             #chomp $return[$i];
             ($which_group{$client}) = ($return[$i] =~ /^.*group: (.*)\;$/);
             $i+=2;
          }
       }
    }

    # Build a list of the max size for each server
    (@return) = `/usr/sbin/mminfo -s $server -r 'client,name,totalsize' -q 'level=full,savetime>last month'`;
    # This utility is used to determine the maximum size of a client full backup
    #print MAIL "	Building max backups for clients on $server\n";
    foreach $record (@return) {
       next if $record =~ /client/;
       chomp $record;
       ($client,$name,$totalsize) = split(' ',$record);
       next if $name =~ /index/;
       next if $totalsize =~ /ROLES/;
       next if $totalsize =~ /SYSTEM/;
       next if $totalsize =~ /ASR/;
       next if $totalsize =~ /FILES/;
       next if $totalsize =~ /OTHER/;
       next if $totalsize =~ /USER/;
       next if $totalsize =~ /DB:/;
       next if $totalsize =~ /STATE:/;
       #print "$client,$name,$totalsize\n";
       $index = "$client|$name";		# Index is client and filesystem
       if (!defined $max{$index} ) {
           $max{"$index"} = $ totalsize;
       } else {
           if ($totalsize > $max{"$index"}) { $max{"$index"} = $totalsize };
       }
    }

    # Now process records to determine max full per client
    foreach $key (sort keys (%max)) {
       ($client,$name) = split(/\|/,$key);
       $client = lc($client);
       if (!defined $total{$client}) {
          $total{$client} = $max{$key};
       } else {
          $total{$client} += $max{$key};
       }
    }
    # total is indexed by lowercase client

    # which_server now contains a list of all clients and which server backs it up.
    print MAIL "\t\tThere are $total_server{$server} VADP clients on server $server\n";
}

#################################################################################################################################
# Get info from RvTools
# RvTools has all the x86 Virtuals Linux, Windows, VADP backups
# All indexed by lowercase client
print "\nBefore Read of Virtual Center Information\n";
read_tabvInfo_old();
print "After Read of Virtual Center Information\n\n";
#################################################################################################################################
# Process by existing VADP BAckup clients
$count = 0;
$total_VMs = 0;
$return = build_output_record(-80,$output,'CLIENT',18,0,-1,-1 ,'',1,18);
$return = build_output_record(0,$output,'LEVEL',10,0,1,1 ,'',19,29);
$header2= build_output_record(0,$output,'MESSAGE',51,0,0,0 ,'',30,80);
print MAIL "$header2\n";
our %Host; 

foreach $key (sort keys (%which_server)) {
  if ($count == 100) {
     $return = build_output_record(-80,$output,'Processing',18,0,-1,-1 ,'',1,18);
     $return = build_output_record(0,$output,'INFO',10,0,1,1 ,'',19,29);
     $return = build_output_record(0,$output,"*** Virtual Machine $total_VMs ***",51,0,0,0 ,'',30,80);
     print MAIL "$return\n";
     $count = 0;
  }
  $count +=1;
  $total_VMs+=1;
  if (!defined $Powerstate{$key}) {
     $return = build_output_record(-80,$output,$key,18,0,-1,-1 ,'',1,18);
     $return = build_output_record(0,$output,'WARN',10,0,1,1 ,'',19,29);
     $return = build_output_record(0,$output,'The Powerstate is undefined',51,0,0,0 ,'',30,80);
     print MAIL "$return\n";
     next;
  } elsif ($Powerstate{$key} =~ /poweredOff/) {
     $return = build_output_record(-80,$output,$key,18,0,-1,-1 ,'',1,18);
     $return = build_output_record(0,$output,'WARN',10,0,1,1 ,'',19,29);
     $return = build_output_record(0,$output,'The VM is powered off and will be ignored',51,0,0,0 ,'',30,80);
     print MAIL "$return\n";
     next;
  }

  # Check to see if the client can be backed up
  $dns = resolv_name($key);
  if ($dns =~ /Not in DNS/) {
     $return = build_output_record(-80,$output,$key,18,0,-1,-1 ,'',1,18);
     $return = build_output_record(0,$output,'ERROR',10,0,1,1 ,'',19,29);
     $return = build_output_record(0,$output,'The Client is not in DNS and will be skipped',51,0,0,0 ,'',30,80);
     print MAIL "$return\n";
     delete $which_group{$key};
     delete $which_server{$key};
     next;
  } elsif ($which_group{$key} =~ /NavyNuclear/ ) {
     $return = build_output_record(-80,$output,$key,18,0,-1,-1 ,'',1,18);
     $return = build_output_record(0,$output,'INFO',10,0,1,1 ,'',19,29);
     $return = build_output_record(0,$output,'Client in Navy Nuclear group and will be skipped',51,0,0,0 ,'',30,80);
     print MAIL "$return\n";
     delete $which_group{$key};
     delete $which_server{$key};
     next;

  } else {
     $ping = pinger($key);
     if ($ping =~ /up/) {
        $port = testport($key,7937);
        if ($port =~ 'Client listening') { 
           ########################################################################################
           # These are tests to determine whether to use VADP or Not
           # The server is in DNS is up and listening on the port and it needs to be added
           ########################################################################################
           if (!defined $total{$key}) {
              $return = build_output_record(-80,$output,$key,18,0,-1,-1 ,'',1,18);
              $return = build_output_record(0,$output,'ERROR',10,0,1,1 ,'',19,29);
              $return = build_output_record(0,$output,'The Client is not being backed up',51,0,0,0 ,'',30,80);
              print MAIL "$return\n";
              next;
           } else {
              if ($total{$key} > 644245094400) {
                 delete $which_group{$key};
                 delete $which_server{$key};
                 $return = build_output_record(-80,$output,$key,18,0,-1,-1 ,'',1,18);
                 $return = build_output_record(0,$output,'WARN',10,0,1,1 ,'',19,29);
                 $return = build_output_record(0,$output,'Client is > 600GB and will not be moved',51,0,0,0 ,'',30,80);
                 print MAIL "$return\n";
                 next;
              }
           }
        } else {
           $port = "Not listening on port 7937";
           $return = build_output_record(-80,$output,$key,18,0,-1,-1 ,'',1,18);
           $return = build_output_record(0,$output,'WARN',10,0,1,1 ,'',19,29);
           $return = build_output_record(0,$output,"Client is not listening on port 7937",51,0,0,0 ,'',30,80);
           print MAIL "$return\n";
        }
     } else {
        $return = build_output_record(-80,$output,$key,18,0,-1,-1 ,'',1,18);
        $return = build_output_record(0,$output,'WARN',10,0,1,1 ,'',19,29);
        $return = build_output_record(0,$output,"$port, $dns, won't ping",51,0,0,0 ,'',30,80);
        print MAIL "$return\n";
        
     }
  }
  # Only trying to find what ESX host the client is on
  # $ key is the client, $HOST{$key} is the IP address of the blade the client is on 
  $hostname = reverse_lookup($Host{$key},$Host{$key});
  if ($hostname =~ /No DNS Name/) {
     $return = build_output_record(-80,$output,$key,18,0,-1,-1 ,'',1,18);
     $return = build_output_record(0,$output,'ERROR',10,0,1,1 ,'',19,29);
     $return = build_output_record(0,$output,"No DNS entry for blade $Host{$key}",51,0,0,0 ,'',30,80);
     print MAIL "$return\n";
     delete $which_group{$key};
     delete $which_server{$key};
  } else {
     $hostname =~ s/\..*$//;
     ($dest_grpname{$key}) = create_group_name_from_esx_host_name($hostname);
     # Check to see the the destination group exists and is enabled
     my $nsrpass =  ". type: NSR group\\;name:$dest_grpname{$key}'\n'show autostart\\;start time\\;schedule time'\n'print";
     (@return3) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $which_server{$key} -i - `;
     foreach $vvv (@return3) {
       next if $vvv =~ /Current query set/;
       if ($vvv =~ /No resources found/) {
          $zone = lc $Cluster{$key};
          $zone =~ s/.*zone//;
          if ( $zone =~  /^\s*$/) {$zone = 1};
          print RAP  "ERROR: The Group $dest_grpname{$key}(Reverse DNS $Host{$key}) Zone $zone for $key doesn't exist on $which_server{$key} and  needs to be created\n";
          print MAIL "ERROR: The Group $dest_grpname{$key}(Reverse DNS $Host{$key}) Zone $zone for $key doesn't exist on $which_server{$key} and  needs to be created\n";
          last;
       } elsif ($vvv =~ /autostart: Disabled/) {
          print RAP  "ERROR: Group $dest_grpname{$key} isn't enabled but client $key is moved\n";
          print MAIL  "ERROR: Group $dest_grpname{$key} isn't enabled but client $key is moved\n";
          last;
       } elsif ($vvv =~ /autostart: Disabled/) {
          print RAP  "ERROR: Group $dest_grpname{$key} isn't enabled but client $key is moved\n";
          print MAIL  "ERROR: Group $dest_grpname{$key} isn't enabled but client $key is moved\n";
          last;
       } elsif ($vvv =~ /schedule time: \S+\;/) {
          print RAP  "WARN: Group $dest_grpname{$key} has scheduled time set\n";
          print MAIL  "WARN: Group $dest_grpname{$key} has scheduled time set\n";
          last;
       }
     }

     if ($which_group{$key} =~ /$dest_grpname{$key}/) {
        # The destination group matches the source group 
        delete $which_group{$key};
        delete $which_server{$key};
        #$return = build_output_record(-80,$output,$key,18,0,-1,-1 ,'',1,18);
        #$return = build_output_record(0,$output,'INFO',10,0,1,1 ,'',19,29);
        #$return = build_output_record(0,$output,"Destination group same as Source no change",51,0,0,0 ,'',30,80);
        #print MAIL "$return\n";
     }
        
  }
}
#################################################################################################################################
print MAIL "\n";
$return = build_output_record(-106,$output,'CLIENT',18,0,-1,-1 ,'',1,18);
$return = build_output_record(0,$output,'BACKUP SERVER',14,0,1,1 ,'',23,36);
$header2= build_output_record(0,$output,'SOURCE/DESTINATION GROUP',25,0,0,0 ,'',36,106);
print MAIL "$header2\n";

$dashes = '-' x 106;
$return = build_output_record(-106,$output,$dashes,106,0,-1,-1 ,'',1,106);
print MAIL "$return\n";
$i = 0;
foreach $val (sort keys %which_group) {
   #print "\n\nKey of which=$val***\n";
   #print "value of which=$which_group{$val}***\n";
   # Host is the ip address of the ESX host
   #print "Host=$Host{$val}***\n";
   if (!defined $dest_grpname{$val}) {
      #print "Destination group not defined for VM ***$val***\n";
      $dest_grpname{$val} = ' ';
   } else {
      #print "Destination group name=$dest_grpname{$val}\n";
   } 
     
   #($source_group) = ($which_group{$val} =~ /.*(VADP-\S+)[,;].*$/);
   $source_group = $which_group{$val};
   if ($source_group =~ /^\s*$/) {
      print MAIL "Source Group undefined or blank\n"; 
   }

   # Check to see if the destination group is the same as the source group
   if ($source_group =~ /$dest_grpname{$val}/) {next};


   @source_array = split(/, /,$source_group);
   undef @dest_array;
   foreach $val (@source_array) {
      if ($val =~ /^VADP-/) {next};
      push (@dest_array,$val);
   }

   # Make sure that INDEX is in the group
   if ( grep(/INDEX/,@dest_array) ) {
      # Has INDEX Group nothing required
   } else {
      push (@dest_array,'INDEX');
   }

   push (@dest_array,$dest_grpname{$val});
   # Put the groups together separated by comma space
   $dest_group = join(", ",@dest_array);

   $return = build_output_record(-106,$output,$i,3,0,1,1 ,'',1,3);
   $return = build_output_record(0,$output,$val,18,0,-1,-1 ,'',6,23);
   $return = build_output_record(0,$output,'SOURCE',10,0,0,0 ,'',24,35);
   $return = build_output_record(0,$output,$source_group,70,0,0,0 ,'',36,106);
   print MAIL "$return\n";


   $return = build_output_record(-106,$output,$which_server{$val},11,0,0,0 ,'',24,35);
   $return = build_output_record(0,$output,$dest_group,70,0,0,0 ,'',36,106);
   print MAIL "$return\n";
   $i++;
   #last if ($i > 120);
   # UPDATE CLIENT moving it to new group
   if ($plan !~ /plan/) {
      #print RAP "INFO: Moved client:$val from group $which_server{$val} to group $dest_group\n";
      print RAP "INFO: Moved client:$val from group sscprodeng2 to group $dest_group\n";
      #update_clients_group ($which_server{$val}, $val, $dest_group); 
      update_clients_group ($which_server{$val}, $val, $dest_group); 
   }
   $return = build_output_record(-106,$output,$dashes,106,0,-1,-1 ,'',1,106);
   print MAIL "$return\n";
}
print MAIL "ENDMAIL\n";
$return = `/usr/bin/sh  $filename  > /dev/null 2>&1`;
close MAIL;
close RAP;

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

