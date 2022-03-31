#!/usr/bin/perl -w
(@count) = `/usr/sbin/mminfo -r nfiles -q 'savetime>last week,level=full'`;
$number_of_files = 0;
foreach $number (@count) {
   $number_of_files += $number;
}
print "There were $number_of_files backed up during the last week\n";
   
