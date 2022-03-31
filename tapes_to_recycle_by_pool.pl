#!/usr/bin/perl -w
$date = `/usr/bin/date '+%m/%d/%y'`;
foreach $server ('sscprodeng','sscprodeng2') {
undef %pools;
chomp $date;
print "\f------- TAPES THAT CAN BE RECYCLED on $server AS OF $date --------\n";;
(@return) = `/usr/sbin/mminfo -s $server -xc, -r \'volume,pool\'  -q \'volretent<$date \' `;
foreach $val (@return) {
   next if $val =~ /volume/;
   next if $val =~ /^\s?$/;
   chomp $val;
   ($volume,$pool) = split(/,/,$val);
   if (defined $pools{$pool}) {
      $pools{$pool} = "$pools{$pool},$volume";
   } else {
      $pools{$pool} = $volume;
   }
}
$across = 7;
foreach $pool (sort keys %pools) {
   (@return) = split(/,/,$pools{$pool});
   $number = $#return+1;
   $per_column = int($number/$across+1);
   print "\n\n------------------------------------------------------------------------\n";
   print "                       Pool = $pool\($number\)\n";
   print "------------------------------------------------------------------------\n";
   $line = '';
   for ($i=0;$i<$per_column;$i+=1) {
     $line ="$return[$i]";
     $col2 = $i  + $per_column;
     if (defined $return[$col2]) {
        $line = "$line     $return[$col2]";
     }
     $col3 = $col2 + $per_column;
     if (defined $return[$col3]) {
        $line = "$line     $return[$col3]";
     }
     $col4 = $col3 + $per_column;
     if (defined $return[$col4]) {
        $line = "$line     $return[$col4]";
     }
     $col5 = $col4 + $per_column;
     if (defined $return[$col5]) {
        $line = "$line     $return[$col5]";
     }
     $col6 = $col5 + $per_column;
     if (defined $return[$col6]) {
        $line = "$line     $return[$col6]";
     }
     $col7 = $col6 + $per_column;
     if (defined $return[$col7]) {
        $line = "$line     $return[$col7]";
     }
     print "$line\n";
   }
}
}
