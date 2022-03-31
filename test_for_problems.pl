#!/usr/bin/perl -w
(@return) = `/usr/sbin/mminfo -s sscprodeng -xc, -avot -r 'name,level,savetime(20),nsavetime' -q 'savetime>two days ago,savetime<yesterday'`;
foreach $val (@return) {
   next if $val =~ /name,level/;
   chomp $val;
   my ($name,$level,$savetime,$nsavetime) = split(/,/,$val);
   ($sec,$min,$hour,$mday,$mon,$year) = localtime($nsavetime);
   $mon+= 1;
   $year-=100;
   print "Savetime=$savetime,\t$mon/$mday/$year $hour:$min:$sec\n";
}

