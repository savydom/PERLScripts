#!/usr/bin/perl -w 
#C27MFOMCNLAN8A
#192.168.190.25
#Full Redundancy
#269.13 GB
#0.00 B
#2

#C27MFOMCNLANP8A
#192.168.190.25
#Full Redundancy
#271.47 GB
#3.46 GB
#3

(@return) = `cat snap.txt`;
$start = 0;
foreach $val (@return) {
   chomp $val;
   if ($start == 0) {
      $server   = $val;
      $vm{$val} = $val; 
   }
   
   if ($start == 1) { 
      $name = reverse_lookup($val,$server);
      $host{$server} = $name;
   } 
   if ($start == 2) { $redun{$server}        =$val}; 
   if ($start == 3) { $total_storage{$server}=$val}; 
   if ($start == 4) { $used_storage{$server} =$val}; 
   if ($start == 5) { $disks{$server}        =$val}; 
   $start +=1;
   if ($val =~ /^\s*$/) { $start = 0 };
}
print "\n\nSorted by Client\n";
foreach $val (sort keys %vm) {
   next if ($used_storage{$val} =~ /0.00 B/);
   print "$val\t$host{$val}\t$redun{$val}\t$total_storage{$val}\t$used_storage{$val}\t$disks{$val}\n"; 
}
print "\n\nSorted by host\n";
foreach $val (sort keys %host) {
   next if ($used_storage{$val} =~ /0.00 B/);
   print "$val\t$host{$val}\t$redun{$val}\t$total_storage{$val}\t$used_storage{$val}\t$disks{$val}\n"; 
}
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

