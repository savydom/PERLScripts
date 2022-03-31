#!/usr/bin/perl -w verage Assessment
unshift (@INC,"/home/scriptid/scripts/BACKUPS/SUBROUTINES");
require handle_nsradmin_line_continuations;
$networker = `/usr/bin/hostname`;
chomp $networker;
# Determine the name, group
my $nsrpass = ". type:NSR client'\n'show name\\;group\\;action'\n'print";
(@return) = handle_nsradmin_line_continuations($networker,$nsrpass);
print "After nsradmin on $networker\n";
# Client name  is mixed case so lower case the names
print "Determing regular/VADP, Prod/Non Prod, Scheduled/Not scheduled on $networker\n";
foreach $val (@return) {
   chomp $val;
   $val =~ s/\;//;
   next if $val =~ /^\s*$/;
   if ($val =~ /name:/) {
      $val =~ s/\s*name: //;
      $name = lc($val);
   } elsif ($val =~ /group/) {
      $val =~ s/\s*group: //;
      if (defined $group{$name}) {
         print "Client: $name: Client defined multiple times $group{$name}, current  groups:$val\n";
      } else {
         $group{$name} = $val;
         undef %checkers;
         (@chkgrp) = split (/,/,$val);
         foreach $ggg (@chkgrp) {
           if (defined $checkers{$ggg}) {
              print "Group already defined for $ggg\n";
           } else {
              $checkers{$ggg} = 1;
           }
         } 
      }
   }
}
