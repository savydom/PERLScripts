#!/usr/bin/perl -w
# Purpose of utility is to move clients to groups based on VLAN
#------------------------------------------------------------------------------------------------------------
$BACKUPSERVER = 'sscprodeng';
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
$val = ". type:NSR client'\n'show name\\;group\\;backup command\\;scheduled backup\\;action'\n'print";
print "Before nsradmin\n";
(@return) = `/usr/bin/echo $val | /usr/sbin/nsradmin -s $BACKUPSERVER -i -`;
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
print "Finished Processing VMware output\n";
# Good to here
#################################################################################################################################
# Get counts for each type of client
# Create new clients if they are viable based on the type of client
#################################################################################################################################
foreach $key (keys %scheduled_backup) {
  $dns = resolv_name($key);
  if ($dns =~ /Not in DNS/) {
     $ping = 'Not in DNS';
     $port = 'Not in DNS';
  } else {
     $ping = pinger($key);
     if ($ping =~ /up/) {
        $port = testport($key,7937);
        if ($port =~ 'Client listening') { 
           ###########    Code to move to group ###############
           # What VLAN
           $vlan = $dns;
     #      $vlan =~ s/^\d\d\d\.\d\d\d\.//;
     #      $vlan =~ s/\d\d\d$//;
     #      print "$key in VLAN = $vlan\n";
     #   } else {
     #       print "$key not listening\n';
        }
     }
  }
}
#################################################################################################################################


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

