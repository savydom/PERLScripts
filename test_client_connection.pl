#!/usr/bin/perl -w
print "Processing Client list\n";
# Loop through the clients
(@clients) = `/usr/bin/cat /home/scriptid/scripts/BACKUPS/linux_sorted.txt`;
foreach $client (@clients) {
   chomp $client;
   print "Client=$client\n";
   $ping = pinger($client);
   print "\t***$ping\n";
   if ($ping =~ /up/) {
#      $port = testport($client,7937);
#   } else {
#      $port = 'Client not listening';
#      next;
   $return  = `/usr/bin/ssh -q $client /bin/uname -a `;
   print "Return = $return\n";
   }
}

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
