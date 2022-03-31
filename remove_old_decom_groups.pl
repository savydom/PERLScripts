#!/usr/bin/perl -w
(@return) = `/usr/sbin/mminfo -xc, -r client,volume -q 'savetime>one year ago' | /usr/bin/sort`;
foreach $val (@return) {
   chomp $val;
   ($client,$volume) = split(/,/,$val); 
   $client = lc $client;
   $backed{$client} = $volume;
}
$nsrpass = ". type:NSR client\\;group:DECOM'\n'show name'\n'print";
(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -i - `;
foreach $client (@return) {
   next if $client =~ /Current query set/;
   next if $client =~ /^\s*$/;
   chomp $client;
   $client =~ s/^\s+name: //;
   $client =~ s/\;//;
   $client = lc $client;
   
   if (defined $backed{$client}) {
      print "\tCan't delete $client\n";
   } else {
      print "*** Delete $client\n";
      $sorted{$client} = 1;
   }
}
print "\n\n\n";
foreach $client (sort keys %sorted) {
   print "Delete $client\n";
}
