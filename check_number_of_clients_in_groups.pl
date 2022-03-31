#!/usr/bin/perl -w verage Assessment
unshift (@INC,"/home/scriptid/scripts/BACKUPS/SUBROUTINES");
require build_output_record;
require handle_nsradmin_line_continuations;
$networker = `/usr/bin/hostname`;
chomp $networker;
# Determine the name, group
my $nsrpass = ". type:NSR client'\n'show name\\;group\\;action'\n'print";
(@return) = handle_nsradmin_line_continuations($networker,$nsrpass);
# Client name  is mixed case so lower case the names
foreach $val (@return) {
   chomp $val;
   $val =~ s/\;//;
   next if $val =~ /^\s*$/;
   if ($val =~ /name:/) {
      $val =~ s/\s*name: //;
      my $name = lc($val);
   } elsif ($val =~ /group/) {
      $val =~ s/\s*group: //;
      (@chkgrp) = split (/,/,$val);
      foreach $ggg (@chkgrp) {
        $ggg =~ s/^\s*//;
        if (defined $gcount{$ggg} ) {
           $gcount{$ggg} += 1;
        } else {
           $gcount{$ggg} = 1;
        }
      } 
   }
}
$return = build_output_record(-47,$output,'GROUP',25,0,-1,-1 ,'',1,25);
$return = build_output_record(0,$output,'Number of Clients',17,0,0,0 ,'',30,47);
#print "$return\n";
foreach $val (sort (keys %gcount)) {
   $return = build_output_record(-47,$output,$val,20,0,-1,-1 ,'',1,25);
   $return = build_output_record(0,$output,$gcount{$val},10,0,0,0 ,'',30,47);
   print "$return\n";
}
