#!/usr/bin/perl -w

###########################################################################################################
# SCRIPT: check_tape_locations
###########################################################################################################
# This script is used to determine if the same tapes show up in both jukeboxes
###########################################################################################################
use Time::Local;
open (TAPE_DELETE,">/home/scriptid/scripts/BACKUPS/tape_delete_list.sh") or die "Could not create /home/scriptid/scripts/BACKUPS/tape_delete_list.sh\n";
(@return) = `/usr/sbin/mminfo -a -s sscprodeng -xc, -r \'volume,volretent,location,%used,pool,written\' -q family=tape`;
   #volume,expires,location,percent-used,pool,written
   # (@return) = `/usr/sbin/mminfo -a -m -s $bserver -q family=tape`;
   #     mminfo -m    very quick and shows all tapes not just those written
   # state volume                  written  (%)  expires     read mounts capacity
   #       UNN568                  2247 GB full  01/13/19    0 KB     6   2540 GB
   #       UNN569                  1533 GB full  01/13/19    0 KB     2   2540 GB
   #       UNN596                     0 KB   0%     undef    0 KB     4   2540 GB
   #       UNN597                     0 KB   0%     undef    0 KB     4   2540 GB
   #       UNN598                     0 KB   0%     undef    0 KB     4   2540 GB
   #
   print "Found $#return tapes currently managed by Networker on sscprodeng\n";
   $now = time;

   # Save all mminfo data
   foreach $val (@return) { 
      chomp $val;
      next if $val =~ /volume,expires,location,percent-used,pool,written/; 
      ($volume,$expires,$location,$pused,$pool,$written) = split(/,/,$val);
      # Expires 09/11/17
      $volume =~ s/\(R\)//;
      if ($volume =~ /^\s*$/) {
         next;
      }   
      $texpired = ' ';
      if ($expires =~ /expired/) {
         $texpired = 'expired';
      } elsif ($expires =~ /undef/) {
         $texpired = 'undef';
      } elsif ($expires =~ /manual/) {
         $texpired = 'manual';
      } else {
         ($m,$d,$y) = split("/",$expires);
         # Convert to timelocal format
         $m -=1;
         $y += 100;
         # just use 12:00 midnight on expiration day
         # Compute seconds since 1970
         $time = timelocal(59,59,23,$d,$m,$y);
         $texpired = $time;
      }
      $volume_1{$volume} = $texpired;
      $volume_1_pool{$volume} = $pool;

   }
(@return) = `/usr/sbin/mminfo -a -s sscprodeng2 -xc, -r \'volume,volretent,location,%used,pool,written\' -q family=tape`;
   #volume,expires,location,percent-used,pool,written
   # (@return) = `/usr/sbin/mminfo -a -m -s $bserver -q family=tape`;
   #     mminfo -m    very quick and shows all tapes not just those written
   # state volume                  written  (%)  expires     read mounts capacity
   #       UNN568                  2247 GB full  01/13/19    0 KB     6   2540 GB
   #       UNN569                  1533 GB full  01/13/19    0 KB     2   2540 GB
   #       UNN596                     0 KB   0%     undef    0 KB     4   2540 GB
   #       UNN597                     0 KB   0%     undef    0 KB     4   2540 GB
   #       UNN598                     0 KB   0%     undef    0 KB     4   2540 GB
   #
   print "Found $#return tapes currently managed by Networker on sscprodeng2\n";

   # Save all mminfo data
   foreach $val (@return) { 
      chomp $val;
      next if $val =~ /volume,expires,location,percent-used,pool,written/; 
      my ($volume,$expires,$location,$pused,$pool,$written) = split(/,/,$val);
      # Expires 09/11/17
      $volume =~ s/\(R\)//;
      if ($volume =~ /^\s*$/) {
         next;
      }   
      $texpired = ' ';
      if ($expires =~ /expired/) {
         $texpired = 'expired';
      } elsif ($expires =~ /undef/) {
         $texpired = 'undef ';
      } elsif ($expires =~ /manual/) {
         $texpired = 'manual';
      } else {
         ($m,$d,$y) = split("/",$expires);
         # Convert to timelocal format
         $m -=1;
         $y += 100;
         # just use 12:00 midnight on expiration day
         # Compute seconds since 1970
         $time = timelocal(59,59,23,$d,$m,$y);
         $texpired = $time;
      }
      $volume_2{$volume} = $texpired;
      if (defined $pool) {
          $volume_2_pool{$volume} = $pool;
      } else {
          print "\tpool not valid for tape $volume\n";
      }

   }

foreach $val (sort keys %volume_1) {
   if (defined $volume_2{$val}) {
      print "Tape $val is shown on both servers, $volume_1{$val}, $volume_2{$val}\n";
      #print "\tExpiration on 1 is $volume_1{$val}\n";
      #print "\tExpiration on 2 is $volume_2{$val}\n";
      if ($volume_2{$val} < $now) {
         print "\t***Delete tape on sscprodeng2 expired\n";
         print TAPE_DELETE "/usr/sbin/nsrmm -s sscprodeng2 -d -y -v $val\n";
      } elsif ($volume_2_pool{$val} =~ /NATO/) {
         print "\tDelete tape on sscprodeng2 in NATO pool\n";
         print TAPE_DELETE "/usr/sbin/nsrmm -s sscprodeng2 -d -y -v $val\n";
      } elsif ($volume_2{$val} > $volume_1{$val}) {
         print "\tERROR: Newer tape is on sscprodeng2\n";
      } else {
         print "\tERROR: data on both copies, newer on sscprodeng\n";
      }
   }
}
      
