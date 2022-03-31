#!/usr/bin/perl -w
$networker = 'sscprodeng';

$val = ". type:NSR client'\n'show name\\;group\\;action'\n'print";
(@return) = `/usr/bin/echo $val | /usr/sbin/nsradmin -s $networker -i -`;
print "Number of records returned = $#return\n";
$output_rec = 0;
$combined[0] = '';
$continue = 0;
# Do it easy
for ($i = 0;$i<$#return;$i++) {
   chomp $return[$i];
   # The addition is to handle multiline groups and there is space between last group and end of line
   if ( $return[$i] =~ /\\$/  || $return[$i] =~ /,\s*$/) {
       print "Found a continuation\n";
      #  Current line has a continuation so don't close out
      $return[$i] =~ s/\\//;
      $continue = 1;
      if (defined $combined[$output_rec]) {
         $combined[$output_rec] = $combined[$output_rec] . $return[$i];
      } else {
         $combined[$output_rec] = $return[$i];
      } 
   } else {
      if ($continue == 1) {
         #working on a record so append it and start new record for next;
         $combined[$output_rec] = $combined[$output_rec] . $return[$i];
      } else {
         $combined[$output_rec] = $return[$i];
      } 
      $output_rec +=1;
      $continue = 0;
   }
}
#foreach $val (@combined) {
#   print "$val\n";
#}
