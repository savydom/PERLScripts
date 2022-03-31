#!/usr/bin/perl -w
# Purpose of utility is to find new clients and to move Windows clients into groups based
# on the blade that they are loaded. We will only move clients that are in the VADP1 groups
# as opposed to the current groups. 
# If VMware clients are larger than "600GB' they will be backed up under a LARGE group.
# If VMware clients are Linux they go into a normal group.  
# Clients are added to backups if the are up, in DNS, and responding on port 7937
# Clients are moved if they are in NORMAL, LARGE,  or VADP1 groups.
# Clients can also be moved based on the time that they take to backup.
# NORMAL groups might not be required, thinking they should be merged into the VADP groups helping 
# reduce the load on the VMware infrastructure. Needs to be looked at.
# First pass tuning will be to connect all clients in the same group based on their blade.
# Parallelism needs to be determined to minimize snapshot load (we have memory size and disk space size
# and even the LUNs).
# Groups are comma separated and will require reading in existing client groups, moving from one VADP1 Group
# To another.
# Handle groups as a client update
#
#------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------
$BACKUPSERVER = 'sscprodeng';
$ALT          = 'sscprodeng2';
$date = `/usr/bin/date '+%y%m%d%H%M%S'`;
chomp $date;
print "Just update RAP log with changes without making actual changes (Yes or NO) : ";
$yesno = <STDIN>;
chomp $yesno;
$yesno = lc($yesno);
$iyesno = 0;
if ($yesno =~ /yes/) {$iyesno = 1};
open (RAP,">/home/scriptid/scripts/BACKUPS/VADP_RAP$date.log") or die "Could not open /home/scriptid/scripts/BACKUPS/VADP_RAP.log\n"; 
(@return) = `/usr/sbin/mminfo -s $BACKUPSERVER -r 'client,name,totalsize' -q 'level=full,savetime>last month'`;
print "Finding largest ciient full backups from the previous month\n";
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
   $index = "$client|$name";
   if (!defined $max{$index} ) {
       $max{"$index"} = $totalsize;
   } else {
       if ($totalsize > $max{"$index"}) { $max{"$index"} = $totalsize };
   }
}
print "Processing the client:filesystem keys to get client totals\n";
# Now process records to determine max full per client
foreach $key (sort keys (%max)) {
   ($client,$name) = split(/\|/,$key);
   $client = lc($client);
   #print "$key,  $max{$key}\n";
   #print "$key, $client, $name,      $max{$key}\n";
   if (!defined $total{$client}) {
      $total{$client} = $max{$key};
   } else {
      $total{$client} += $max{$key};
   }
}
# total is indexed by lowercase client

#################################################################################################################################
# Build a list indexed by client from networker using the lower case for:
#	$backup_command 	-> backup Command 
#	$group 			-> group
#	$scheduled_backup	-> are the backups scheduled
# Info extracted
#                        name: C27ACEcnlaP8B;
#            scheduled backup: Disabled;
#                       group: DECOM;
#              backup command: nsrvadp_save;
#################################################################################################################################
$val = ". type:NSR client'\n'show name\\;scheduled backup\\;action'\n'print";
(@return) = `/usr/bin/echo $val | /usr/sbin/nsradmin -s $ALT -i -`;
foreach $val (@return) {
   chomp $val;
   $val =~ s/\;//;
   next if $val =~ /^\s*$/;
   if ($val =~ /name:/) {
      $val =~ s/\s*name: //;
      $name = lc($val);
      #print "Name=$name\n";
   }  elsif ($val =~ /scheduled backup/) {
      $val =~ s/\s*scheduled backup: //;
      # set to 1
      $scheduled_backup2{$name} = grep(/Enabled/,$val);
      #print "Scheduled2 $name $scheduled_backup2{$name}\n";
   }
}
$val = ". type:NSR client'\n'show name\\;group\\;backup command\\;scheduled backup\\;action'\n'print";
print "Before nsradmin\n";
print "After nsradmin\n";
# Client name  is mixed case so lower case the names
foreach $val (@return) {
   chomp $val;
   $val =~ s/\;//;
   next if $val =~ /^\s*$/;
   if ($val =~ /name:/) {
      $val =~ s/\s*name: //;
      $name = lc($val);
      #print "Name=$name\n";
   } elsif ($val =~ /backup command/) {
      $val =~ s/\s*backup command: //;
      $backup_command{$name} = grep (/nsrvadp/,$val);
      #print "Backup command= $backup_command{$name}\n";
   } elsif ($val =~ /group/) {
      $val =~ s/\s*group: //;
      $group{$name} = $val;
      #print "Group=$group{$name}\n";
      # Keep tract of current groups for later
      $current_groups{$val} = 1;
   }  elsif ($val =~ /scheduled backup/) {
      $val =~ s/\s*scheduled backup: //;
      $scheduled_backup{$name} = grep(/Enabled/,$val);
      #print "scheduled_backup=$scheduled_backup{$name}\n";
   }
}
# All indexed by lowercase client
print "After processing nsradmin\n";
#
# RVTools_tabvInfo.csv
# Annotation can have commas
my (
   $junk, $junk2,
   %DNS_Name,
   %Powerstate,
   %Connection_state,
   %Guest_state,
   %Heartbeat,
   %Consolidation_Needed,
   %PowerOn,
   %Suspend_time,
   %CPUs,
   %Memory,
   %NICs,
   %Disks,
   %Network_1,
   %Network_2,
   %Network_3,
   %Network_4,
   %Resource_pool,
   %Folder,
   %vApp,
   %DAS_protection,
   %FT_State,
   %FT_Latency,
   %FT_Bandwidth,
   %FT_Sec_Latency,
   %Boot_Required,
   %Provisioned_MB,
   %In_Use_MB,
   %Unshared_MB,
   %HA_Restart_Priority,
   %HA_Isolation_Response,
   %Cluster_rules,
   %Cluster_rule_names,
   %Path,
   %Annotation,
   %AOR,
   %Domain,
   %Billable,
   %Command,
   %Environment,
   %System_ABBR,
   %Status,
   %System_ID,
   %Datacenter,
   %Cluster,
   %Host,
   %OS,
   %VM_Version,
   %UUID,
   %Object_ID 
);
#################################################################################################################################
#Build a list of all the attributes returned from RVtools tabvInfo
# Indexed by the lowercase VMware name  
# VM,DNS Name,Powerstate,Connection state,Guest state,Heartbeat,Consolidation Needed,PowerOn,Suspend time,CPUs,Memory,NICs,Disks,
# Network #1,Network #2,Network #3,Network #4,Resource pool,Folder,vApp,DAS protection,FT State,FT Latency,FT Bandwidth,
# FT Sec. Latency,Boot Required,Provisioned MB,In Use MB,Unshared MB,HA Restart Priority,HA Isolation Response,Cluster rule(s),
# Cluster rule name(s),Path,Annotation,AOR,Domain,Billable,Command,Environment,System ABBR,Status,System ID,Datacenter,Cluster,Host,
# OS,VM Version,UUID,Object ID
#################################################################################################################################
open (RECORDS,"</home/scriptid/scripts/BACKUPS/RVTools3.8/RVTools_tabvInfo.csv") or die "Could not open /home/scriptid/scripts/BACKUPS/RVTools3.8/RVTools_tabvInfo.csv";
print "Start VMware record read\n";
(@records) = (<RECORDS>);
print "After VMware record read\n";
print "Processing VMware records\n";
foreach $record (@records) {
   # Need to determine how many fields are returned inbto @_ array
   # Because the Annotation field can have commas 
   (@fields) = split(/,/,$record);
   chop $record;
   $VMmixed = $fields[0];
   $VMmixed =~ s/,.*$//;
   #print "VM=$VMmixed\n";
   next if $VMmixed =~ 'VM';
   $VM = lc($VMmixed);
   # Handle all the junk names
   $iskip=0;
   if ($VM =~ /off/) {$iskip=1};
   if ($VM =~ /baseline/) {$iskip=1};
   if ($VM =~ /^2008/) {$iskip=1};
   if ($VM =~ /^2012/) {$iskip=1};
   if ($VM =~ /[\&]/) {$iskip=1};
   if ($VM =~ /[\(]/) {$iskip=1};
   if ($VM =~ /[\)]/) {$iskip=1};
   if ($VM =~ /decom/) {$iskip=1};
   if ($VM =~ /\.old/) {$iskip=1};
   if ($iskip == 1) {
      print RAP "WARN: Skipped VM $VM because of name rules\n";
      next;
   }
   #$VMwareMixedCaseName{$VM} = $VMmixed;
   # Everything below indexed by lower case 
  ($DNS_Name{$VM},
  $Powerstate{$VM},
  $Connection_state{$VM},
  $Guest_state{$VM},
  $Heartbeat{$VM},
  $Consolidation_Needed{$VM},
  $PowerOn{$VM},
  $Suspend_time{$VM},
  $CPUs{$VM},
  $Memory{$VM},
  $NICs{$VM},
  $Disks{$VM},
  $Network_1{$VM},
  $Network_2{$VM},
  $Network_3{$VM},
  $Network_4{$VM},
  $Resource_pool{$VM},
  $Folder{$VM},
  $vApp{$VM},
  $DAS_protection{$VM},
  $FT_State{$VM},
  $FT_Latency{$VM},
  $FT_Bandwidth{$VM},
  $FT_Sec_Latency{$VM},
  $Boot_Required{$VM},
  $Provisioned_MB{$VM},
  $In_Use_MB{$VM},
  $Unshared_MB{$VM},
  $HA_Restart_Priority{$VM},
  $HA_Isolation_Response{$VM},
  $Cluster_rules{$VM},
  $Cluster_rule_names{$VM},
  $Path{$VM},
  #$Annotation{$VM}
  $AOR{$VM},
  $Domain{$VM},
  $Billable{$VM},
  $Command{$VM},
  $Environment{$VM},
  $System_ABBR{$VM},
  $Status{$VM},
  $System_ID{$VM},
  $Datacenter{$VM},
  $Cluster{$VM},
  $Host{$VM},
  $OS{$VM},
  $VM_Version{$VM},
  $UUID{$VM},
  $Object_ID{$VM}
  ) = (@fields)[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,
                -15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1];
  #print "VM=$VM, DNS_NAME{$VM}, $Host{$VM}, $OS{$VM}\n";
}
print "Finished Processing VMware output\n";
# Good to here
#################################################################################################################################
# Get counts for each type of client
# Create new clients if they are viable based on the type of client
#################################################################################################################################
print "After database load\n"; 
$total_count=0;
$total_backed_up=0;
$total_not_backed_up=0;
$total_linux = 0;
$total_server_2003 = 0;
$total_server_2008 = 0;
$total_server_2012 = 0;
$total_server_other = 0;
$total_clients_that_could_be_added = 0;
$total_decomm = 0;
$total_disabled = 0;
$total_poweredoff = 0;
undef %VMsperBlade;
$count = 0;
$total_VMs = 0;
print "Processing clients to determine if they can be backed up\n";
foreach $key (sort keys (%DNS_Name)) {
  if ($key =~ /\s/) {
     print "Found a blank in the hostname $key\n";
     next;
  }
  $total_count+= 1;
  if ($count == 100) {
     print "Prosessing VM $total_VMs\n";
     $count = 0;
  }  
  $count +=1;
  if ($OS{$key} =~ /Linux/) {
     $total_linux += 1;
  }elsif ($OS{$key} =~ /Server 2003/) {
     $total_server_2003 += 1;
  }elsif ($OS{$key} =~ /Server 2008/) {
     $total_server_2008 += 1;
  }elsif ($OS{$key} =~ /Server 2012/) {
     $total_server_2012 += 1;
  }elsif ($OS{$key} =~ /Other/) {
     $total_server_other += 1;
  } else {
     print RAP "WARN: No defined OS for $key, $OS{$key}\n";
  }
  $total_VMs +=1;
  #print "VMname=$key\n";
  if (defined $backup_command{$key} ) { 
     # Found a backup
      if ($group{$key} !~ /DECOM/) {
         if ($scheduled_backup{$key} ==  1) {
             if ($scheduled_backup2{$key} ==  1) {print RAP "POTENTIAL ERROR: $key scheduled on both servers\n"};
             if ($Powerstate{$key} =~ /poweredOff/) {
                print RAP "WARN: $key not backed up but it is powered off\n";
                $total_poweredoff += 1;
                $total_not_backed_up += 1;
             } else { 
                #print "****************Backed up $key\n";
                $total_backed_up += 1;
             }
          } else {
             if ($scheduled_backup2{$key} ==  1) {
                print RAP "INFO: Server $key backed up on $ALT\n";
                $total_backed_up += 1;
             } else {
                print RAP "POTENTIAL ERROR: $key not backed up because not scheduled\n";
                $total_not_backed_up += 1;
                $total_disabled += 1;
             }
          }
      } else {
          print RAP "WARN: $key not backed up because Decomm'd\n";
          $total_decomm += 1;
      }
  } else {
     if ( !defined $scheduled_backup2{$key} ) {
        $total_not_backed_up += 1;
        print RAP "ERROR: $key not in backups\n";
     } else {
         if ($scheduled_backup2{$key} == 1) {
           $total_backed_up += 1;
         } else {
           print "Server=$key\n"; 
           print "scheduled_backup2=$scheduled_backup2{$key}\n";
           print " backup_command=$backup_command{$key}\n"; 
           print " scheduled_backup2=$scheduled_backup{$key}\n";
           print "Server=$key, backup_command=$backup_command{$key}\n";
           print RAP "ERROR: $key not scheduled on either server\n";
         }
     }
  }

  if (!defined $total{$key}) {	# No client 
     $dns = resolv_name($key);
     if ($dns =~ /Not in DNS/) {
        $ping = 'Not in DNS';
        $port = 'Not in DNS';
     } else {
        $ping = pinger($key);
        if ($ping =~ /up/) {
           $port = testport($key,7937);
           if ($port =~ 'Client listening') { 
              ########################################################################################
              # These are tests to determine whether to use VADP or Not
              $vadp  = 1;	# VADP
              $large = 0;
              # The server is in DNS is up and listening on the port and it needs to be added
              if (!defined $total{$key}) {
                 if (defined $scheduled_backup2{$key} ) {
                    if ($scheduled_backup2{$key} ==  0) {print RAP "WARN: $key not backed up\n"};
                 }
              } else {
                  if ($total{$key} > 644245094400) {
		     $vadp  = 0};  					# Don't use VADP for clients larger than 600GB
                     $large = 1;						# Put it in the large group
                  }
              }
              if ($OS{$key} =~ /Linux/) {$vadp = 0};			# Don't use VADP for Linux servers
              # Client needs to be updated to handle VMware and use the original case sensitive host name
              # Could create base client and then update for VMware 
              # Make networker client name lower case
	      # Pass in the VMware name which is case sensitive for VADP
              $total_clients_that_could_be_added += 1;
              # $d = $Disks{$key} + 1;
              # $s = 10;
              #########(@return) = create_client($client,$group,$schedule,$browse,$reten,$par,$vadp,$large,$VMware_Name);
        } else {
           $port = 'Client not listening';
        }
     }
     $pete = 0;
  } else {
     $pete=$total{$key};
     $pete=$pete/1024/1024/1024;
     $pete = format_number($pete,1,'l',6);
     $pete =~ s/\s//g;
  }
  if (!defined $VMsperBlade{$Host{$key}}) {
     #$VMsperBlade{$Host{$key}} = $key . "(D$Disks{$key},M$Memory{$key},$pete)";
     $VMsperBlade{$Host{$key}} = $key;
     $hostname = reverse_lookup($Host{$key},$key);
     $VMsperBladeName{$Host{$key}} = $hostname;
     $VMnames{$hostname} = $hostname; 
     #$VMsperBladeNameLine2{$Host{$key}} = "Memory: $Memory{$key}";
     #$VMsperBladeNameLine3{$Host{$key}} = "Disks: $Disks{$key}";
     #$VMsperBladeNameLine3TotalDisk{$Host{$key}} = $Disks{$key};
     #$VMsperBladeNameLine3TotalMemory{$Host{$key}} = $Memory{$key};
     #######$VMsperBladeNameLine4SNAPSHOT{$Host{$key}} = $ppp;
     #$VMsperBladeNameLine5FullBackup{$Host{$key}} = $pete;
  } else {
     $hostname = reverse_lookup($Host{$key},$key);
     $VMnames{$hostname} = "$VMnames{$hostname}:$hostname"; 
     #$VMsperBlade{$Host{$key}} = "$VMsperBlade{$Host{$key}}:$key(D$Disks{$key},M$Memory{$key},$pete)";
     $VMsperBlade{$Host{$key}} = "$VMsperBlade{$Host{$key}}:$key";
     #$VMsperBlade{$Host{$key}} = "$VMsperBlade{$Host{$key}}:$key(D$Disks{$key},M$Memory{$key},$pete)";
     #$VMsperBladeNameLine2{$Host{$key}} = "$VMsperBladeNameLine2{$Host{$key}}:$Memory{$key}";
     #$VMsperBladeNameLine3{$Host{$key}} = "$VMsperBladeNameLine3{$Host{$key}}:$Disks{$key}";
     #$VMsperBladeNameLine4SNAPSHOT{$Host{$key}} = "$VMsperBladeNameLine4SNAPSHOT{$Host{$key}}:$ppp";
     #$VMsperBladeNameLine3TotalDisk{$Host{$key}} += $Disks{$key};
     #$VMsperBladeNameLine3TotalMemory{$Host{$key}} += $Memory{$key};
     #$VMsperBladeNameLine5FullBackup{$Host{$key}} = "$VMsperBladeNameLine5FullBackup{$Host{$key}}:$pete";
  } 
}
#################################################################################################################################
print "Finished processing VMs\n";
foreach $val (sort keys %VMsperBladeName) {
   ($grpname) = create_group_name_from_esx_host_name($VMsperBladeName{$val});
   print "***************$VMsperBladeName{$val}, $grpname\n";
   @return = update_group($grpname,$VMsperBlade{$val},%group);
   #print "  $VMsperBladeNameLine3TotalMemory{$val}  $VMsperBladeNameLine2{$val}\n";
   #print "  $VMsperBladeNameLine3TotalDisk{$val}    $VMsperBladeNameLine3{$val}\n";
   #print "  $VMsperBladeNameLine4SNAPSHOT{$val}\n";
   #print "  $VMsperBladeNameLine5FullBackup{$val}\n";
}

print "\n\nTotal VM's in VMware     = $total_count\n";
print "Total VM's backed up         = $total_backed_up\n";
print "Total VM's not backed up     = $total_not_backed_up\n";
print "VM's that could be backed up = $total_clients_that_could_be_added\n";
print "Total VM's powered off       = $total_poweredoff\n";
print "Total VM's Decomm'd          = $total_decomm\n";
print "Total VM's Disabled          = $total_disabled\n";
print "Total Linux Servers          = $total_linux\n";
print "Total 2003                   = $total_server_2003\n";
print "Total 2008                   = $total_server_2008\n";
print "Total 2012                   = $total_server_2012\n";
print "Total other                  = $total_server_other\n";
$total_oss = $total_linux+ $total_server_2003 + $total_server_2008 + $total_server_2012 + $total_server_other;
print "Total defined OSs            = $total_oss\n";
$unknown = $total_count - $total_oss;
print "Undefined OSs                = $unknown\n";


sub reverse_lookup {
    ($check,$key) = @_;
    my $IP = $check;
    if ($IP !~ /\./) {
       print RAP "WARN: No reverse lookup for $key\n";
    } else {
       use Socket;
       $iaddr = inet_aton("$IP");
       $name = gethostbyaddr($iaddr, AF_INET);
       if ( !defined $name ) {
          print RAP "WARN: No reverse lookup for $key, $IP\n";
          $name = "No DNS Name";
       }
    }
    return $name;
}

sub format_number {
   my ($val,$places,$justify,$width) = @_;
   my $text1;
   $text=reverse $val;
   $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
   $val=reverse $text;
   $val =~ s/(\d*\.\d{$places})\d*/$1/;
   $length = length($val);
   if ($justify eq 'l') {
      $start = 0;
   } elsif ($justify eq 'c') {
      $start = int( ($width-$length)/2 );
   } elsif ( $justify eq 'r') {
      $start = $width-$length;
   } else {
      print RAP "PROGRSM ERROR in formatnumber\n";
  }
   $final = ' ' x $width;
   substr($final,$start,$length)=$val;
   return $final;
}

sub pinger{
   ($pingee) = @_;
   $up = 'down';
   # Test to see if machine is up
   $ping = `/usr/sbin/ping  $pingee   2 2>/dev/null`;
   if ($ping =~ /is alive/) {$up=' up'};
   return $up;
}

sub testport{
   ($host,$port) = @_;
   use IO::Socket;
   $| = 1;  # Flush Buffer immediately
   $socket = IO::Socket::INET->new(PeerAddr => $host, PeerPort =>$port, Timeout => 2);
   if ($socket) {
      $return = "  Client listening";
   } else {
      $return = "Client not listening";
   }
}

sub create_client {
    my ($client,$group,$schedule,$browse,$reten,$par) = @_;
    $val = "create type: NSR client\\;name:$client\\;group: $group\\;schedule: $schedule\\;start time: $start\\;browse policy: $browse\\;retention policy: $reten\\;savegrp parallelism: $par\\;options: No index save\\;";
    (@return) = `/usr/bin/echo $val | /usr/sbin/nsradmin -s $BACKUPSERVER -i -`;
}

sub create_groups_from_tabvHost {
   print "Entering create_groups_from_tabvHost $menu\n";
   $auto = 'Disabled';
   $par  = 8;
   $val = ". type:NSR GROUP\\;show name;action'\n'print";
   (@return) = `/usr/bin/echo $val | /usr/sbin/nsradmin -s $BACKUPSERVER -i -`;
   print "After nsradmin\n";
   # Client name  is mixed case
   foreach $group (@return) {
      chomp $group;
      next if $group =~ /^\s*$/;
      $group =~ s/\s*name: //;
      $current_groups{$group} = 1;
   }
   
   open (VHOST,"</CIFS/RVToolsOutput/RVTools_tabvHost.csv") or die "Could not open </CIFS/RVToolsOutput/RVTools_tabvHost.csv\n";
   
   #Host,Datacenter,Cluster,CPU Model,Speed,HT Available,HT Active,# CPU,Cores per CPU,# Cores,CPU usage %,# Memory,Memory usage %,Console,# NICs,# HBAs,# VMs,VMs per Core,# vCPUs,vCPU
   #s per Core,vRAM,VM Used memory,VM Memory Swapped,VM Memory Ballooned,VMotion support,Storage VMotion support,Current EVC,Max EVC,ESX Version,Boot time,DNS Servers,DHCP,Domain,DNS S
   #earch Order,NTP Server(s),Time Zone,Time Zone Name,GMT Offset,Vendor,Model,BIOS Version,BIOS Date,Object ID
   
   #192.168.104.190,SSC NOLA,OPSMGMT M1000 zone,Intel(R) Xeon(R) CPU           X5660  @ 2.80GHz,2792,True,True,2,6,12,27,196595,62,0,4,8,20,1.6666666666666666666666666667,52,4.33333333
   #33333333333333333333,136792,19854,0,0,True,True,,intel-westmere,VMware ESXi 5.5.0 build-3568722,3/15/2016 7:47:54 AM,"192.168.104.240, 192.168.104.241",False,sscnola.oob,sscnola.oo
   #b,nolatimeserver.sscnola.oob,UTC,UTC,0,Dell Inc.,PowerEdge M610,3.0.0,1/31/2011 12:00:00 AM,host-80184
   
   (@esxhosts) = <VHOST>;
   foreach $esx (@esxhosts) {
      chop $esx;
      next if $esx=~/Host,Datacenter,Cluster/;
      my (
      $hostip,
      $datacenter,
      $cluster,
      $CPU_Model,
      $Speed,
      $HT_Available,
      $HT_Active,
      $Number_CPU,
      $Cores_per_CPU,
      $Number_Cores,
      $CPU_usagePercent,
      $Memory,
      $Memory_usagePercent,
      $Console,
      $numberNICs,
      $numberHBAs,
      $VMs,
      $VMsperCore,
      $number_vCPUs,
      $vCPUperCore,
      $vRAM,
      $VM_Used_memory,
      $VM_Memory_Swapped,
      $VM_Memory_Ballooned,
      $VMotion_support,
      $Storage_VMotion_support,
      $Current_EVC,
      $Max_EVC,
      $ESX_Version,
      $Boot_time,
      $DNS_Servers,
      $DHCP,
      $Domain,
      $DNS_Search_Order,
      $NTP_Servers,
      $Time_Zone,
      $Time_Zone_Name,
      $GMT_Offset,
      $Vendor,
      $Model,
      $BIOS_Version,
      $BIOS_Date,
      $Object_ID
      ) =  split(/,/,$esx);
   
      #print "$hostip, $datacenter, $cluster, $CPU_Model, $Speed, $HT_Available, $HT_Active, $Number_CPU, $Cores_per_CPU, $Number_Cores, $CPU_usagePercent, $Memory, $Memory_usagePercent, $Console,
      #\t$numberNICs,$numberHBAs, $VMs, $VMsperCore, $number_vCPUs, $vCPUperCore, $vRAM, $VM_Used_memory, $VM_Memory_Swapped, $VM_Memory_Ballooned, $VMotion_support, $Storage_VMotion_support,$Current_EVC,
      #\t$Max_EVC, $ESX_Version, $Boot_time, $DNS_Servers, $DHCP, $Domain, $DNS_Search_Order, $NTP_Servers, $Time_Zone, $Time_Zone_Name, $GMT_Offset, $Vendor, $Model, $BIOS_Version,
      #$BIOS_Date, $Object_ID\n\n";
      $name = reverse_lookup($hostip,'GroupCheck');
      $name =~ s/\.sscnola\.oob//;
      $name =~ s/\-[Ee][Ss][Xx]//;
      $name =~ s/_/-/g;
      $name = lc $name;
      # Backslash escapes in strings
      # \u Force next character to upper case
      # \U Force following characters to Upper case
      # \L Force following characters to lower case
      # \l Force next character to lowercase
      $name =~ s/([\w']+)/\u\L$1/g;
      $grpname = "VADP-$name";
      print "Hostip=$hostip, Name=$grpname\n";
      $return = create_group($grpname,$par,$auto);
   }
}

sub create_group {
    my ($group,$par,$auto) = @_;
    # Pass in the group name
    # name:
    # comment:
    # autostart: (Enabled  Disabled)
    # start time: "23:25"
    # interval: "24:00"
    # force incremental: [Yes No]
    # savegrp parallelism: 8
    # client retries: 0
    # options: No index save
    # schedule: [Full Every Saturday Full Every Friday VADP Friday Night Full VADP Saturday Night Full]
    if ( !defined $current_groups{$group} ) {
       if ($group =~ /prod/) {
          # Put in Saturday night schedule
          $sched = 'VADP Saturday Night Full';
          $start = "23:00";
       } else {
          $sched = 'VADP Friday Night Full';
          $start = "19:00";
       }
       #$val = "create type:NSR group\\;name: $group\\;start time: $start\\;autostart: $auto\\;savegrp parallelism: $par\\;options: No index save\\;schedule: $sched\\;";
       $val = "create type:NSR group\\;name: $group\\;autostart: $auto\\;savegrp parallelism: $par\\;options: No index save\\;schedule: $sched\\;";
       #print "Missing ESX Host Group:  $group\n$val\n";
       if ($menu == 1) {
          (@return) = `/usr/bin/echo $val | /usr/sbin/nsradmin -s $BACKUPSERVER -i - `;
          foreach $vvv (@return) {
              print "Error: $vvv\n";
          } 
       }
    }
}

sub resolv_name {
    my ($check) = @_;
    $return = "Not in DNS";
    push(@DNS,'192.168.104.240','192.168.104.241','192.168.104.56','192.168.104.57');
    push(@SUF,'sscnola.oob','sscnola.oob','cdc.local','cdc.local');
    my $index =-1;
    foreach $dns (@DNS) {
       $index+=1;
       my (@dum) = `/usr/sbin/nslookup $check.$SUF[$index] $dns 2>&1 `;
       $bc =0;
       foreach $val (@dum) {
         #$val =~ s/\s//g;
         chomp $val;
         if ( $bc == 1 ) {
            if ( $val =~ /Address:/ ) {
               $return = "  In DNS";
               goto RETURN;
            } else {
               print "problem in nslookup\n";
            }
         }
         if ($val =~ /can't find $check/ ) {
            goto RETURN;
         } elsif ($val =~ /Name:/) {
           $bc=1;
         }
       }
    }
    RETURN:
    return $return;
}


#sub reverse_lookup {
#    use Socket;
#    my ($ip) = @_;
#    $name = gethostbyaddr( inet_aton($ip), AF_INET);
#}

sub update_group {
    my ($grp,$list,%group) = @_;
    my (@clients) = split(/:/,$list);
    foreach $clnt (@clients) {
      # Create clients in $group and INDEX ignoring the current group
      if (!defined $group{$clnt}) {
         print RAP "GROUP_MOVE - backup client $clnt doesn't exist in group $grp\n";
      } else {
         next if $group{$clnt} =~ /$grp/;
         print RAP "GROUP_MOVE - client $clnt moved from group $group{$clnt} to group $grp\n";
         print "GROUP_MOVE - client $clnt moved from group $group{$clnt} to group $grp\n";
         $val =  ". type: NSR client\\;name:$clnt'\n'update group:INDEX, $grp'\n'";
         print "Val in update=$val\n";
         if ($iyesno == 0) {
            #(@return) = `/usr/bin/echo $val | /usr/sbin/nsradmin -s $BACKUPSERVER -i - `;
            foreach $vvv (@return) {
               print RAP "\tINFO: $vvv\n";
            }
         }
      }
    }
}

sub create_group_name_from_esx_host_name {
      ($esx_host) = @_;
      $esx_host = lc $esx_host;
      $esx_host =~ s/\.sscnola\.oob//;
      $esx_host =~ s/\-[Ee][Ss][Xx]//;
      $esx_host =~ s/_/-/g;
      # Backslash escapes in strings
      # \u Force next character to upper case
      # \U Force following characters to Upper case
      # \L Force following characters to lower case
      # \l Force next character to lowercase
      $esx_host =~ s/([\w']+)/\u\L$1/g;
      $grpname = "VADP-$esx_host";
      print "ESX Host=$esx_host, Group=$grpname\n";
      return $grpname;
}
