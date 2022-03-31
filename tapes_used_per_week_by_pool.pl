#!/usr/bin/perl -w
$date = `/usr/bin/date '+%m/%d/%y'`;
chomp $date;
foreach $server ('SSCPRODENG','SSCPRODENG2') {
   undef %pools;
   $weeks = 4;
   print "\n\nAverage Consumed Tapes on $server by Pool Over The Last Four Weeks $date\n";;
   (@return) = `/usr/sbin/mminfo -s $server -xc, -r \'volume,pool\'  -q \"savetime>$weeks weeks ago\" `;
   foreach $val (@return) {
      next if $val =~ /volume/;
      next if $val =~ /^\s?$/;
      chomp $val;
      my ($volume,$pool) = split(/,/,$val);
      if (defined $pools{$pool}) {
         $pools{$pool} +=1;
      } else {
         $pools{$pool} = 1;
      }
   }
   foreach $pool (sort keys %pools) {
      $count = int($pools{$pool}/$weeks+1);
      print "There were $count tapes used per week for pool $pool\n";
   }
}
