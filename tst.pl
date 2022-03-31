#!/usr/bin/perl -w 
(@servers) = ('sscprodeng','sscprodeng2');
$nsrpass = ". type:NSR client'\n'show name\\;scheduled backup\\;schedule\\;group\\;action'\n'print";
(@return) =  `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $servers[0] -i -`;
foreach $val (@return) {
   chomp $val;
   print "VAL=$val\n";
}

