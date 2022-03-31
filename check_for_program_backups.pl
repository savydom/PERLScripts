#!/usr/bin/perl -w
#
# This program is used to validate that program servers have been backed up during a certain time period
# It will use the start time of the backupscd ..
#
print "Enter the name of the program to check: ";
$program = <STDIN>;
chomp $program;
$program = lc $program;
# Need to generate a list of servers to search for pattern matches
# Generate for the last month
print "Query for list of backup clients\n";
(@return) = `/usr/sbin/mminfo  -avot -r 'client' -q 'savetime>last month' | /usr/bin/sort | /usr/bin/uniq`;
print "Return from Query for list of backup clients\n\n\n";
foreach $val (@return) {
   chomp $val;
   $val = lc $val;
   $sindex = 0;
   $eindex = 10;
   if ($val =~ /$program/) {
      $exit = 0;
      #print "Begin query for client $val\n";
      (@days) = `/usr/sbin/mminfo -avot -r 'savetime(8)' -q 'client=$val,savetime>05/01/2016,savetime<06/01/2016' | /usr/bin/sort | /usr/bin/uniq`;
      print "Server: $val\n";
      TOP:
      #print "Eindex=$eindex, Day=$#days\n";
      if ($eindex > $#days) {
         $eindex = $#days;
         $exit = 1;
      }
      #print "Sindex=$sindex, Eindex=$eindex\n";
      print "\t";
      for ($i=$sindex;$i<$eindex;$i++) {
         chomp $days[$i];
         #print "$i $days[$i], ";
         print "$days[$i], ";
      } 
      print "\n";
      
      if ($exit==1) {
         print "\n";
         next;
      }
      $sindex = $eindex;
      $eindex += 10;
      goto TOP;
   }
}

