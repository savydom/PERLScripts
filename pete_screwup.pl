#!/usr/bin/perl -w
######pete_screwup.txt
$SOURCE      = 'sscprodeng';
(@screwup) = `/usr/bin/cat pete_screwup.txt`;
foreach $messed (@screwup) {
   chomp $messed;
   if ($messed =~ /NSR client/) {
      $messed =~ s/^.*resource, //;
      $messed =~ s/://;
      $client = $messed;
      print "Client=$messed\n";
   } elsif ($messed =~ /Full Every Sunday/) {
      # nothing to do
   } elsif ($messed =~ /schedule/) {
      $reset_schedule{$client} = $messed;
      $reset_schedule{$client} =~ s/^.*schedule: //;
      $reset_schedule{$client} =~ s/;//;
   }
}
$count = 0;
foreach $client (sort keys %reset_schedule) {
    $count += 1;
   $nsrpass = ". type:NSR client\\;name:$client'\n'update schedule: $reset_schedule{$client}";
   print "NSRPASS=$nsrpass\n";
   (@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -i -`;
   print "@return\n";
   #last if $count>2;
}
