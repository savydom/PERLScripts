#!/usr/bin/perl -w
use Time::Local;
print "Before Query\n";
# Determine the maximum backup size over the previous 4 weeks
$nsrpass = ". type:NSR client'\n'show name\\;comment\\;action'\n'print";
(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s sscprodeng -i -`;
foreach $val (@return) {
   chomp $val;
   next if $val =~ /^\s*$/;
   next if $val =~ /Current query set/;
   if ($val =~ /\s+name:/) {
      $val =~ s/^\s+name: //;
      $val =~ s/\;//;
      $name = $val;
      $name = lc($name);
  } elsif ($val =~ /\s+comment:/) {
      $val =~ s/^\s+comment: //;
      $val =~ s/\;//;
      $comment = $val;
      #print "Comment=$comment\n";
      if ( $comment =~ /P:/ ) {
         $ProdOrNot{$name} = 'P';
      } else {
         $ProdOrNot{$name} = 'N';
      }
   } else {
      #print "Val=$val\n";
   }
}
#foreach $val (sort keys %ProdOrNot) {
#   print "***$ProdOrNot{$val}***\n";
#}
(@return) = `/usr/sbin/mminfo -a -xc, -r 'client,name,sscreate(20),sscomp(20),totalsize' -q 'savetime>28 days ago,level=full'`;
print "After Query\n";
#sscutran1  /var/share/pkg                    04/30/16 23:41:41   04/30/16 23:41:50   04/30/16 23:41:52       2536
#%convert_month = (Jan,0,Feb,1,Mar,2,Apr,3,May,4,Jun,5,Jul,6,Aug,7,Sep,8,Oct,9,Nov,10,Dec,11);
print "Before Totalsize and Parameter loop\n";
foreach $record (@return) {
   chop $record;
   ($client,$filesystem,$starttime,$endtime,$totalsize) = split (/,/,$record);
   # if ($filesystem =~ /WINDOWS/) {print "$client,$filesystem,$starttime,$endtime,$totalsize\n"};
   next if $client =~ /sscprodeng/;
   next if !defined $totalsize;
   #next if $filesystem =~ /VOLUME\{/;
   $totalsize = int ($totalsize);
   next if $totalsize < 40;    
   $client = lc $client;
   $key = "$client\|$filesystem";
   $value = "$starttime\|$endtime\|$totalsize";
   if (!defined $max_size{$key}) {
      $max_size{$key} = $totalsize;
      $parameters{$key} = $value;
   } else {
      if ($totalsize > $max_size{$key}) {
         $max_size{$key} = $totalsize;
         $parameters{$key} = $value;
      }
   }
}
print "Before backup speed loop\n";
#Build a list of the backup speeds
foreach $key (keys %parameters) {
   ($client,$filesystem) = split (/\|/,$key);
   ($starttime,$endtime,$totalsize) = split(/\|/,$parameters{$key});
   ($mon,$mday,$yr,$hr,$min,$sec) = ($starttime =~ /(\d\d)\/(\d\d)\/(\d\d) (\d\d)\:(\d\d)\:(\d\d)/);
   if ($key =~ /sscmgt4c/) {print "Key=$key,$starttime,$endtime,$totalsize\n"};
   if ( (defined $mon) || (int($mon) > 0) ) {
      $mon = $mon -1;
      $yr += 100;
      $epoch_start_seconds = timelocal($sec, $min, $hr, $mday, $mon, $yr);
      if ($key =~ /sscmgt4c/) {print "Key epochstart=$key,$starttime,$sec, $min, $hr, $mday, $mon, $yr,$epoch_start_seconds\n"};

      ($mon,$mday,$yr,$hr,$min,$sec) = ($endtime =~ /(\d\d)\/(\d\d)\/(\d\d) (\d\d)\:(\d\d)\:(\d\d)/);
      #if ($key =~ /sscmgt4c/) {print "**End Key,end,mon,mday,yr,hr,min,s=$key,$endtime,$mon,$mday,$yr,$hr,$min,$sec\n"};
      if ( (defined $mon) ) {
         $mon = int($mon); 
         if ( ($mon < 0 ) || ($mon > 12) ) {
            #print "$record\n";
            $del = 0;
         } else {
            $mon = $mon -1;
            $yr += 100;
            $epoch_end_seconds = timelocal($sec, $min, $hr, $mday, $mon, $yr);
            if ($key =~ /sscmgt4c/) {print "**Key epochend=$key,$endtime,$sec, $min, $hr, $mday, $mon, $yr,$epoch_end_seconds\n"};
            $del = $epoch_end_seconds - $epoch_start_seconds;
            if (defined $group_start{$client}) {
               if ($epoch_start_seconds < $group_start{$client}) {$group_start{$client} = $epoch_start_seconds};
            } else {
               $group_start{$client} = $epoch_start_seconds;
            }
            if (defined $group_end{$client}) {
               if ($epoch_end_seconds > $group_end{$client}) {$group_end{$client} = $epoch_end_seconds};
            } else {
               $group_end{$client} = $epoch_end_seconds;
            }
         }
      } else {
         $del = 0;
      } 
   } else {
      $del = 0;
   }
   $delta{$key} = $del; 
   #if ($key =~ /sscmgt4c/) {print "****Key epochstart,epochend,delta,maxsize:$key,$epoch_start_seconds,$epoch_end_seconds,$delta{$key},$max_size{$key}\n"};
}
# Want to determine the average backup time of the different clients assume end to end and not concurrent
print "Before max time  loop\n";
foreach $val (sort keys %max_size) {
   # Keys will be sorted by client
   ($client,$filesystem) = split (/\|/,$val);
   if ( !defined $max_time{$client} ) {
      $max_time{$client} = $delta{$val};
      $max_client_size{$client} = $max_size{$val};
   } else {
      $max_time{$client} += $delta{$val};
      $max_client_size{$client} += $max_size{$val};
   }
   #if ($client =~ /sscmgt4c/) { print "$client,$filesystem,$max_time{$client},$max_client_size{$client}\n"};
}
print "Print loop\n";
print "Client Name                    Backup Time       Size             Cont Speed       Server Speed\n";
$total_production = 0;
$total_non_production = 0;
foreach $client (sort keys %max_time) {
   if ($max_time{$client} < 1) {
      $speed = 0;
   } else {
      $speed = $max_client_size{$client}/$max_time{$client};
   }
   $speed=$speed/1024/1024;
   $wall_clock = $group_end{$client} - $group_start{$client};
   if ($wall_clock < 1) {
      $server_speed = 0;
   } else {
      $server_speed = $max_client_size{$client} / $wall_clock /1024 /1024;
   } 

   $temp=' 'x100;
   $prt1=sprintf"%3s","\($ProdOrNot{$client}\)";
   substr($temp,0,3) = "$prt1";
   $prt1=sprintf"%-22s",$client;
   substr($temp,3,22) = "$prt1";
   #$prt1=sprintf"%-10.0f",$max_time{$client};
   $time = $max_time{$client}/60;
   $prt1=sprintf"%10.0f",$time;
   substr($temp,26,14) = "$prt1 min ";
   $msize = $max_client_size{$client}/1024/1024/1024;
   if ($ProdOrNot{$client} =~ /P/) {
      $total_production += $msize;
   } else {
      $total_non_production += $msize;
   }
   $prt1=sprintf"%10.0f",$msize;
   substr($temp,40,13)= "$prt1 GB";
   $prt1=sprintf"%10.0f",$speed;
   substr($temp,53,15)= "$prt1 MB/s";
   $prt1=sprintf"%10.0f",$server_speed;
   substr($temp,68,15)= "$prt1 MB/s";
   $prt1=sprintf"%10.0f",$wall_clock;
   substr($temp,83,15)= "$prt1s";
   print "$temp\n";
   #print "$client = Time:$max_time{$client},  Size:$max_client_size{$client}, Speed:$speed MB/s Server Speed=$server_speed\n";
}
print "    Total Production Backups = $total_production\n";
print "Total Non Production Backups = $total_non_production\n";
