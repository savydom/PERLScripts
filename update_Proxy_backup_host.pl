#!/usr/bin/perl -w
# Update vcenter name in application group
# Purpose of utility is to find new clients and to move Windows clients into groups based
$nsrpass = ". type:NSR client'\n'show name\\;Proxy backup host'\n'print";
(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s sscprodeng -i -`;
foreach $record (@return) {
   next if $record =~ /client/;
   chomp $record;
   $record =~ s/;$//;
   if ($record =~ /^\s+name: /) {
      $record =~ s/^\s+name: //;
      $client = lc $record;
      #print "Client=***$client***\n";
   } elsif ($record =~ /^\s+Proxy backup host: /) {
      $record =~ s/^\s+Proxy backup host: //;
      if ($record =~ /^$/) {
         print "proxy **$record** not set $client\n";
         next;
      } elsif ($record !~ /bkproxy/ ) {
         print "Proxy set to **$record** on client $client\n"; 
         #$nsrpass =  "\. type: NSR client\\;name:$client'\n'update Proxy backup host: bkproxy'\n'";
         #print "NSRPASS=$nsrpass\n";
         #(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -i - `;
         #foreach $vvv (@return) {
         #  print "INFO: $vvv\n";
         #}
      } else {
         print "$client=$record***\n"; 
       
      }
   }
}
