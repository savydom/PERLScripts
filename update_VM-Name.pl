#!/usr/bin/perl -w
# Update vcenter name in application group
# Purpose of utility is to find new clients and to move Windows clients into groups based
$nsrpass = ". type:NSR client'\n'show name\\;backup command'\n'print";
(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s sscprodeng -i -`;
foreach $record (@return) {
   next if $record =~ /client/;
   chomp $record;
   $record =~ s/;$//;
   if ($record =~ /^\s+name: /) {
      $record =~ s/^\s+name: //;
      $client = lc $record;
      #print "Client=***$client***\n";
   } elsif ($record =~ /^\s+backup command: /) {
      #print "Record=$record***\n";
      $record =~ s/^\s+backup command: //;
      if ($record =~ /nsrvadp/) {
         $backup_command{$client} = $record;
      } else {
         $backup_command{$client} = '';
      }
      #print "Client=$client, Command=$backup_command{$client}\n";
   }
}
# All indexed by lowercase client
print "After processing nsradmin\n";
#
# RVTools_tabvInfo.csv, This needs to be kept up based on the version of RVTools
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
open (RECORDS,"</home/scriptid/scripts/BACKUPS/VMware55/RVTools_tabvInfo.csv") or die "Could not /home/scriptid/scripts/BACKUPS/VMware55//RVTools_tabvInfo.csv";
print "Start record read\n";
(@records) = (<RECORDS>);
print "After record read\n";
foreach $record (@records) {
   # Need to determine how many fields are returned inbto @_ array
   # Because the Annotation field can have commas 
   (@fields) = split(/,/,$record);
   chop $record;
   $VMmixed = $fields[0];
   $VMmixed =~ s/,.*$//;
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
  $VMwareMixedCaseName{$VM} = $VMmixed;
  #print "VM=$VM, Mixed=$VMwareMixedCaseName{$VM}\n";
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
# L O O P  T H R O U G H  A L L  T H E  C L I E N T S  W I T H  D N S  N A M E S 
foreach $key (sort keys (%DNS_Name)) {
  #print "Key=$key\n";
  ##################### C O D E  T O  B U I L D  C L I E N T  I F  I T  D O E S N 'T  E X I S T #######################
  #$dns = resolv_name($key);
  #if ($dns =~ /Not in DNS/) {
  #} else {
  $check_name = $key;
  $lower = lc $check_name;
  #print "Lower=$lower, Mixed=$VMwareMixedCaseName{$key}***\n";
  if (defined $backup_command{$lower}) {
     if ($backup_command{$lower} =~ /nsrvadp/) {
        #print "Lower Key=$lower\n";
        #print "Backup Command=$backup_command{$lower}\n";
        #print "Mixed=$VMwareMixedCaseName{$key}\n";
        if ($lower =~ /\s+/) {
           print "*************Spaces in name skipping\n";
           next;
        }
        #$nsrpass =  "\. type: NSR client\\;name:$lower'\n'update application information:VADP_VM_NAME=$VMwareMixedCaseName{$key},VADP_HOST=vmware55-nola,VADP_DISABLE_CBT=YES,VADP_TRANSPORT_MODE=NBD,VADP_DISABLE_FLR=NO,VADP_QUIESCE_SNAPSHOT=NO'\n'";
        $nsrpass =  "\. type: NSR client\\;name:$lower'\n'update application information:VADP_VM_NAME=$VMwareMixedCaseName{$key},VADP_HOST=vmware55-nola'\n'";
        print "NSRPASS=$nsrpass\n";
        (@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -i - `;
        foreach $vvv (@return) {
           print "INFO: $vvv\n";
        }
      } else {
         print "Backup command not defined for client $lower\n";      
      }
  }   
}

