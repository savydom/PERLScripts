#!/usr/bin/perl -w
$yesno = "Y\nN";
$server = 'sscprodeng';
print "/usr/bin/cat  ./abc  | /usr/sbin/nsrjb -vvv -d -s $server 2>&1\n";
$return = `/usr/bin/cat  ./abc | /usr/sbin/nsrjb -j ADIC_LTO5 -vvv -d -s $server`;
print "Return=$return\n";
