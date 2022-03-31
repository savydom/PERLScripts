#!/usr/bin/perl -w
# Used to determine which fulls failed from the previous Friday
# Peter Reed (aVenture)
# 11 29, 2016
# 1.08

# Determine the group, backup command, and scheduled backup
(@servers) = ('sscprodeng', 'sscprodeng2');
$val = ". type:NSR client'\n'show name\\;group\\;backup command\\;scheduled backup\\;comment\\;action'\n'print";
print "Before nsradmin\n";
foreach $networker (@servers) {
   (@return) = `/usr/bin/echo $val | /usr/sbin/nsradmin -s $networker -i -`;
   print "After nsradmin on $networker\n";
   # Client name  is mixed case so lower case the names
   print "Determing regular/VADP, Prod/Non Prod, Scheduled/Not scheduled on $networker\n";
   foreach $val (@return) {
      chomp $val;
      $val =~ s/\;//;
      next if $val =~ /^\s*$/;
      if ($val =~ /name:/) {
         $val =~ s/\s*name: //;
         $name = lc($val);
      } elsif ($val =~ /backup command/) {
         $val =~ s/\s*backup command: //;
         $backup_command{$name} = grep (/nsrvadp/,$val);
      } elsif ($val =~ /group/) {
         $val =~ s/\s*group: //;
         $group{$name} = $val;
         ## Keep tract of current groups for later
         #$current_groups{$val} = 1;
      }  elsif ($val =~ /scheduled backup/) {
         $val =~ s/\s*scheduled backup: //;
         if (!defined $scheduled_backup{$name}) { $scheduled_backup{$name} = 0};
         # only care is server is enabled
         if ( grep(/Enabled/,$val) ) {
            # found one previously
            if ($scheduled_backup{$name} =~ /ssc/) {
               # Special case for multiple definitions for same client
               if ($scheduled_backup{$name} ne $networker) {print "****Client $name $scheduled_backup{$name} is enabled on multiple servers\n"};
            } else {
               $scheduled_backup{$name} = $networker;
            } 
         }

      }  elsif ($val =~ /comment/) {
         $val =~ s/\s*comment: //;
         $comment{$name} = $val;
      }
   }
}
#(@totalsize) = `mminfo -xc,  -m'`;
foreach $networker (@servers) {
   print "Determing all clients from the last three weeks on server $networker\n"; 
   (@backup_clients)=`/usr/sbin/mminfo -xc, -s $networker -r client -q 'savetime>three weeks ago' | /usr/bin/sort | /usr/bin/uniq`;
   foreach $client (@backup_clients) {
      chomp $client;
      $client = lc($client);
      $grouper{$client} = 1;
   }
}
#/usr/sbin/mminfo -xc, -a -o ct -r client,savetime,name -q 'savetime>last friday,level=full'
foreach $networker (@servers) {
   print "Determining clients with full backups since last Friday on server $networker\n"; 
   (@backup_full ) = `/usr/sbin/mminfo -xc, -a -o ct -s $networker -r 'client,savetime,totalsize'  -q 'savetime>last friday,level=full' | /usr/bin/sort | /usr/bin/uniq`;
   undef %full_backup;
   foreach $val (@backup_full) {
      chomp $val;
      next if ($val=~/lient/);
      next if ($val=~/^\s*$/);
      next if ($val=~/invalid client name/);
      ($client,$savetime,$totalsize) = split(/,/,$val);
      $client = lc($client);
      $key = "$client:$savetime";
      if (defined $server_size{$key}) {
         $server_size{$key} += $totalsize;
      } else {
         $server_size{$key} = $totalsize;
      }
   }
}

# Process through to determine the maximum size backed up in a day
# This is to handle multiple failed fulls
foreach $key (sort keys %server_size) {
   ($client,$savetime) = split(/:/,$key);
   if (defined $full_backup{$client} ) {
      if ( $server_size{$key} >$full_backup{$client} ) {$full_backup{$client} = $server_size{$key}};
   } else {
      # Assume that 3G is smallest server
      if ($comment{$client} =~ /F:/) {
          ($check_size) = $comment{$client} =~ /.*F:(\d*\.*\d*)\;.*/;
          $check_size  = $check_size*1000000;
      } else {
          $check_size=3000000000;
      }
      if ($server_size{$key} > $check_size) { $full_backup{$client} = $server_size{$key} }
   }
}
#print "Begin full backup\n";
#foreach $val (sort keys %full_backup) {
#   print "Server = $val, size=$full_backup{$val}\n";
#}

print "Processing Client list\n";
# Loop through the clients
foreach $client (sort keys %grouper) {
   next if (defined $full_backup{$client});
   $ping = pinger($client);
   if ($ping =~ /up/) {
      $port = testport($client,7937);
   } else {
      $port = 'Client not listening';
   }
   if (!defined $comment{$client}) {
      print "*** Client $client comment not defined\n";  
      $comment{$client} = '';
   }
   if ($comment{$client} !~ /D:/) {
      $dns = resolv_name($client);
      if ($dns =~ /In DNS/) {
         if ($ping =~ /up/) {
            if ($port =~ /Client listening/) {
               if (defined $scheduled_backup{$client}) {
                  if ($scheduled_backup{$client} =~ /ssc/) {
                     $lower = lc($group{$client});
                     $networker_server = $scheduled_backup{$client};
                     next if $lower =~ /decom/;
                     if ( $lower  =~ /prod/) {
                        if ( $backup_command{$client} == 1) {
                          $return = append_group('Automated-PROD-VADP-Reruns',$client,$networker_server);
                        } else {
                          $return = append_group('Automated-PROD-Reruns',$client,$networker_server);
                        }
                        print "****PROD Client $client, no full backups since last Friday, $ping, $dns, $port\n";
                     } else {
                        if ( $backup_command{$client} == 1 ) {
                          $return = append_group('Automated-NON-PROD-VADP-Reruns',$client,$networker_server);
                        } else {
                          $return = append_group('Automated-NON-PROD-Reruns',$client,$networker_server);
                        }
                        print "****NON PROD Client $client, no full backups since last Friday, $ping, $dns, $port\n";
                     }
                  } else {
                     print "*** Client $client is not scheduled for backups\n";
                  }
               }
            } else {
               print "*** Client $client is not listening on port 7937\n";
            }
        } else {
            print "*** Client $client is down\n";
        } 
      } else {
         print "*** Client $client not in DNS\n";  
      }
   } else {
         print "*** Client $client is marked as DCOM'd, $ping, $dns, $port\n";
         if ( $group{$client} !~ /DECOM/ ) { print "		Not in DECOM group\n"};
         if ( $scheduled_backup{$client} == 1 ) { print "		Not disabled\n"};
   }
}
     
#sub format_number {
#   my ($val,$places,$justify,$width) = @_;
#   my $text1;
#   $text=reverse $val;
#   $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
#   $val=reverse $text;
#   $val =~ s/(\d*\.\d{$places})\d*/$1/;
#   $length = length($val);
#   if ($justify eq 'l') {
#      $start = 0;
#   } elsif ($justify eq 'c') {
#      $start = int( ($width-$length)/2 );
#   } elsif ( $justify eq 'r') {
#      $start = $width-$length;
#   } else {
#      print "Error in formatnumber\n";
#  }
#   $final = ' ' x $width;
#   substr($final,$start,$length)=$val;
#   return $final;
#}
sub pinger{
   ($pingee) = @_;
   $up = 'down';
   # Test to see if machine is up
   $ping = `/usr/sbin/ping  $pingee   5 2>/dev/null`;
   if ($ping =~ /is alive/) {$up=' up'};
   return $up;
}
sub testport{
   ($host,$port) = @_;
   use IO::Socket;
   $| = 1;  # Flush Buffer immediately
   $socket = IO::Socket::INET->new(PeerAddr => $host, PeerPort =>$port, Timeout => 5);
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
       my (@dum) = `/usr/sbin/nslookup $check.$SUF[$index] $dns`;
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
sub append_group {
    my ($group,$clnt,$networker_server) = @_;
    #my $a = 1;
    #if ($a == 1) {return};
    #foreach $clnt (@clients) {
      chomp $clnt;
      print "Client=$clnt added to group $group on $networker_server\n";;
    goto RETURN;
      # Create clients in $group and INDEX ignoring the current group
      $val =  ". type: NSR client\\;name:$clnt'\n'append group:$group'\n'";
      (@return) = `/usr/bin/echo $val | /usr/sbin/nsradmin -s $networker_server -i - `;
      foreach $vvv (@return) {
         print "INFO: $vvv\n";
      }
    #}
    RETURN:
}
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
         (@return) = `/usr/bin/echo $val | /usr/sbin/nsradmin -i - `;
         foreach $vvv (@return) {
            print RAP "\tINFO: $vvv\n";
         }
      }
    }
}
