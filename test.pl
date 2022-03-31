#!/usr/bin/perl -w
(@return) = `/usr/bin/ssh -q sscprodeng "/usr/sbin/mminfo -a -s sscprodeng -xc, -r \'volume,volretent,location,%used,pool,written\' -q \'family=tape\' 2>&1"`;
foreach $val (@return) {
  print "Val=$val";
}
