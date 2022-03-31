#!/usr/bin/perl -w

###########################################################################################################
# SCRIPT: tapes_to_pull_from_jukebox.pl
###########################################################################################################
#  Tapes to pull from Jukebox
#  
#  This utility is used to determine how many tapes are required for the next week's backups.
#  It looks back four weeks and averages the amount of data backed up over that time by pool.
#  It adds 10% to these totals and then starts looking for tapes that can be used.
#  This utility looks at the amount of data written to tape and not the number of tapes used.
#  This eliminates issues where only partial tapes are written.
#  It determines the average compression rate and average compression size.
#  It then gets lists of all tapes on sscprodeng and sscprodeng2 and their status and expiration times.
#  It tries to optimize the number of weeks of storaage in the jukbox to minimize tape mounts for recoveries.
#  
#  It displays a chart by pool showing tapes based on usage divided by average tape capacity.
#  The chart shows:
#  1.)  average weekly use is how many tapes, were used during each of the previous four weeks
#  2.)  emhows how many empty pool tapes are in the jukebox
#  3.)  The next column is the surplus tapes available for the pool
#  4.)  The next column show the number of partially filled tapes for each pool
#  5.)  Column 5 is the number of full tapes in the jukebox used for recovers
#  6.)  The 6th column is the optimal number of tapes per pool to achieve the maximum number of weeks for recovery
#  
#  If there is a long weekend or some special case, additional tapes can be added by entering a percentage (0-50%)
#  
#  The program then begins to look for tapes it can use for the current week's backups.
#  It looks for in order by pool:
#  1.)  Partially filled tapes in the jukebox
#  2.)  Empty tapes in the jukebox
#  3.)  Unlabeled tapes in the jukebox
#  4.)  Partially filled tapes in the tape library on the backup server
#  5.)  Expired tapes in the tape library
#  6.)  Empty tapes in the tape library on the backup server
#  7.)  Partially filled tapes in the tape library on the second backup server (sscprodeng2)
#  8.)  Expired tapes in the tape library on the second backup server (sscprodeng2)
#  9.)  Empty tapes in the tape library on the backup server on the second backup server (sscprodeng2)
#  
#  It then prints a list of the tapes it thinks will be used for the next week's backups.
#          The document is output to the printer by the ADIC.
#  
#  It prints a list of the tapes that will need to loaded. Pulled from the tape library.
#          The document is output to the printer by the ADIC.
#  
#  It then prints a list of the tapes that will need to be labeled. Partially filled tapes are not labeled.
#          The document is output to the printer by the ADIC.
#  
#  If there are not enough empty slots in the jukebox (12 are reserved for recovers), then full tapes need to be ejected.
#          A list of tapes to be ejected is also output on the printer.
#  
#  
#  The program then asks that the mailslots be emptied and starts ejecting tapes 24 at a time
#  It prompts to empty the mailslots and then ejects the next set until are out.
#  If the full tapes are on the table, the plastic cases can be removed from them can be used to
#          store the write protected ejected full tapes.
#  
#  The program then requests that the tapes pulled from the tape library be inserted 24 at a time into the mailslots.
#  
#  Operations is then complete and the remainder of the processes are performed in the backround.
#  
#  -------------------------------------------------------------------------------------------------------
#  
#  A file with the tapes to be labeled is created
#          /home/scriptid/scripts/BACKUPS/LABELING/tape_list_date
#  
#  Three jobs are spawned that read the file and if required delete the tapes from the tape library on
#          sscprodeng or sscprodeng2.  They then label the tapes into the correct pools three at a time
#          until all the taped have been labeled.

# This script is used to load a set of weekly tapes into the jukebox.
# It first determines how much storage space is required per pool on a weekly basis by looking at the last 
# FOUr weeks of backups.  It then adds 10% to each pool. It allows an additional percentage to be added.
# It checks the average tape compression over the four weeks to determine the number of tapes needed to
# meet the current week's storage requirements. 
#
# It then starts looking for tapes.  In order it checks by pool:
#	1. Partially filled tapes in the jukebox
#	2. Empty or expired tapes in the jukebox
#	3. Unlabeled tapes in the jukebox
#	4. Partially filled tapes on the shelves
#	5. Empty or expired tapes on the shelves
#	6. Empty or expired tapes on the shelves from the alternate server sscprodeng2
# 
# It will then create a list of reusable and partially filled tapes to be used
# It then creates a list of tapes that need to be loaded and prints that list on the printer by the ADIC
# It then creates a list of tapes to be ejected trying to optimize the retention time in the jukebox.
# It ejects the tapes automatically waiting for operations to empty the mailslots
# It then loads the pulled tapes into the jukebox
# It deletes tapes from the tape library as required and then labels them
###########################################################################################################

#
###########################################################################################################
# 
# There are five statuses for tape %status{$volume}:
#	(b) Blank and labeled
#	(u) Blank and unlabeled
#	(e) Written but expired
#	(f) Written Full 
#	(p) Written Partial
# There are four possible locations %tlocation{$volume}
#	(j) In virtual jukebox on primary server
#	(a) In virtual jukebox on alternate backup server
#	(l) In tape library at site
#	(o) Offsite
#
# When extracting and replacing tapes the locations and states are important
#	
# The oldest tapes should be exported from the jukebox to maintain the highest number of cycles possible for 
#	recovers.  The 'Written Full' tapes should be exported and by pool.  We don't need 50 Nato pool tapes
#	when we use only 2 per week.
#
# The number of tapes required per week per pool is determined from the previous three weeks history
#
# The order of tape usage is:
# 	In jukebox partially filled
#	In jukebox empty
#	In tape library for primary tape range and partially filled
#	In tape library for primary tape range and empty
#	In tape library for alternate tape range (borrow tapes to even out primary and alternate)
#
# Want to know which server %tserver{$volume}
#	(p) Primary
#	(a) Alternate
###########################################################################################################
# 
# Want to first determine the number of tapes required per period per pool
# want to add a percentage on top of the number of tapes required per pool
# Don't want to add more tapes if already have enough in pool
# Only count full tapes, too much to worry about partial tapes
# Assume that 25 slots are kept free in the jukebox
# Assume 6 cleaning slots and 300 slots per jukebox
# printers
#	syseng		- printer on 4th deck 
#	ops1brother	- printer by tape drives
#	dba		- Printer by dbas
#
# Rather than dealing with physical tapes and arbitrary storage per tape4 compute space required and display relative tapes
#$default_printer = 'syseng';
$default_printer = 'ops1brother';
unshift (@INC,"/home/scriptid/scripts/BACKUPS/SUBROUTINES");
require build_output_record;

use Time::Local;
$server = `/usr/bin/hostname`;
if ($server =~ /sscut/) {$server='sscprodeng'};
chomp $server;
$empty = 4/1000/1000/1000;
$fudge = 1.1;
if ($server =~ /^sscprodeng$/) {
   $mailslots         = 24;
   $jukebox           = 'ADIC_LTO5';
   $ajukebox          = 'ADIC_LTO5_2';
   $slots_per_jukebox = 600;
   $devices           = 12;
   $storagenode       = 'sscustno1';
   $free_slots        = 12;
   $cleaning_slots    = 8;
   $capacity          = 2.6;	# Terabytes Conservative
   $test_volume_name  = 'UN';
   $lower_tape_range  = 4000;
   $upper_tape_range  = 9989;
   #$tester	      = "456N";
   $tester	      = "456789ABN";
   $tester_alt	      = "789";
   $alternate	      = 'SSCPRODENG2';
   $pull_pool         = 'SSCNOLA2LTO5';
   $eject_fill_pool   = 'SSCNOLALTO5';
   # Factor to apply to number of tapes required
   $slop=1.0;
   $raw_tape_capacity = 1.5;
   $minimum_tapes{'AFTDClone'} = 2;
   $max_usuable_slot  = 594;
} elsif ($server =~ /^sscprodeng2$/) {
   $mailslots         = 24;
   $jukebox           = 'ADIC_LTO5_2';
   $ajukebox          = 'ADIC_LTO5';
   $slots_per_jukebox = 300;
   $devices           = 12;
   $storagenode       = '';
   $free_slots        = 12;
   $cleaning_slots    = 6;
   $capacity          = 2.6;	# Terabytes
   $test_volume_name  = 'UN';
   $tester	      = "789AB";
   $tester_alt	      = "456N";
   $lower_tape_range  = 7000;
   $upper_tape_range  = 9989;
   $alternate	      = 'sscprodeng';
   $pull_pool         = 'SSCNOLALTO5';
   $eject_fill_pool   = 'SSCNOLA2LTO5';
   # Factor to apply to number of tapes required
   $slop=1.0;
   $raw_tape_capacity = 1.5;
   $max_usuable_slot  = 592;
} elsif ($server =~ /^sdprodeng$/) {
   $mailslots         = 12;
   $jukebox           = 'SD-LTO3';
   $ajukebox          = '';
   $slots_per_jukebox = 541;
   $devices           = 10;
   $storagenode       = '';
   $free_slots        = 12;
   $cleaning_slots    = 10;
   $capacity          = 1.0;	# Terabytes
   $alternate	      = '';
   $lower_tape_range  = 0;
   $upper_tape_range  = 9999;
   # Factor to apply to number of tapes required
   $slop=1.0;
   $raw_tape_capacity = .4;
   $max_usuable_slot  = 592;
} 

$date              = `/usr/bin/date '+20%y%m%d%H%M%S''`;
chomp $date;
$weeks             = 4;


$dash = '-'x84;

push (@servers,$server); 
#if ($alternate !~ /^\s*$/) {push (@servers,$alternate)};

# Compute seconds at 1 year ago
$now      = time;
# Extra time for leap year
$year     = 3600*24*366;
$year_ago = $now - $year;


#******************************************************************************************************
#
# Build hashes based on volume name for pools, capacity, location, expiration, percent_used
#
#*****************************************************************************************************

# There are five statuses for tape %tstatus{$volume}:
#	(b) Blank and labeled
#	(u) Blank and unlabeled
#	(e) Written but expired
#	(f) Written Full 
#	(p) Written Partial
# There are five possible locations %tlocation{$volume}
#	(j) In virtual jukebox on primary server
#	(a) In virtual jukebox on alternate backup server
#	(l) In tape library at site
#	(o) Offsite
# Want to know which server %tserver{$volume}
#	(p) Primary
#	(a) Alternate
foreach $bserver (@servers) {
   print "\n\n$dash\n";
   print "  Collecting data about all tapes used on backup server $bserver $date\n";;
   print "$dash\n\n";

   # Collect a list of tapes(volume) and their expiration times(volretent) and locations(location)
   print "It will take some time to get a list of all tapes in the tape library for $bserver.\n";

   # This will generate a complete list of tapes including those that are just labeled with nothing written to them
   #print "/usr/bin/ssh -q $bserver \"/usr/sbin/mminfo -a -s $bserver -xc, -r \'volume,volretent,location,%used,pool,written\' -q family=tape 2>&1\n";
   (@return) = `/usr/bin/ssh -q $bserver "/usr/sbin/mminfo -a -s $bserver -xc, -r \'volume,volretent,location,%used,pool,written\' -q \'family=tape\' 2>&1"`;
   

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
   print "Found $#return tapes currently managed by Networker on $bserver\n";

   # Save all mminfo data
   $calculated_capacity = 0;
   $number_of_tapes_used_for_capacity = 0;
   foreach $val (@return) { 
      next if $val =~ /^\s*$/;
      next if $val=~/^Filesystem/;
      next if $val=~/^backup/;
      chomp $val;
      next if $val =~ /volume,expires,location,percent-used,pool,written/; 
      ($volume,$expires,$location,$pused,$pool,$written) = split(/,/,$val);
      next if defined $tserver{$volume};
      # Expires 09/11/17
      next if $pool =~ /Offsite/;
      next if $pool =~ /Decade/;
      $volume =~ s/\(R\)//;
      if ($volume =~ /^\s*$/) {
         next;
         # The tape is unlabeled Networker doesn't know about it have to get barcode from jukebox
         #$tstatus{$volume} = 'u';
         #$texpiration{$volume} = $year_ago;
         #$tlocation{$volume} = 'j';
      }   
      #$all{$volume} = 1;
      $tserver{$volume} = $bserver;
      $texpired{$volume} = ' ';
      if ($expires =~ /expired/) {
         $texpired{$volume} = 'f';
         #print "Texpired\{$volume\} = $texpired{$volume}\n";
         $texpiration{$volume} = $year_ago-$year;
      } elsif ($expires =~ /undef/) {
         $texpired{$volume} = ' ';
         $texpiration{$volume} = $year_ago-$year;
      #} elsif ($expires =~ /append/) {
      #   $texpired{$volume} = ' ';
      #   $texpiration{$volume} = $year_ago-$year;
      } elsif ($expires =~ /manual/) {
         $texpired{$volume} = 'm';
      } else {
         ($m,$d,$y) = split("/",$expires);
         # Convert to timelocal format
         $m -=1;
         $y += 100;
         # just use 12:00 midnight on expiration day
         # Compute seconds since 1970
         $time = timelocal(59,59,23,$d,$m,$y);
         if ($time < $now) {$texpired{$volume} = 'e'};
         $texpiration{$volume} = $time;
      }

      # There are five possible locations %tlocation{$volume}
      #	(j) In virtual jukebox on primary server
      #	(a) In virtual jukebox on alternate backup server
      #	(l) In tape library at site in primary server
      #	(m) In tape library at site in alternate server
      #	(o) Offsite
      #	(d) Don't know
      if ($location eq $jukebox) {
         $tlocation{$volume} = 'j';
      } elsif ($location eq $ajukebox) {
         $tlocation{$volume} = 'a';
      }elsif ($location =~ 'Off') {
         $tlocation{$volume} = 'o';
      } elsif ($location =~ /^\s*$/ || (lc($location) =~ /shelf/) ) {
         if ($bserver eq $alternate) {
            # Has the tape been transferred to the primary server from the alternate
            if (defined $tlocation{$volume}) {
               # has been moved
            } else {
               $tlocation{$volume} = 'm';
            }
          } else {
               $tlocation{$volume} = 'l';
          }
      } else {
         $tlocation{$volume} = 'd';
         print "Don't understand the location $location for tape $volume\n";
      } 
      $tpool{$volume}     = $pool;

      # Writen is in KB
      ($value,$units) = split(/\s+/,$written);
      $units = uc $units;
      if ($units =~ /KB/) { 
         $volume_size{$volume}  = $value/1000/1000/1000;
      } elsif ($units =~ /MB/) {
         $volume_size{$volume} = $value/1000/1000;
      } elsif ($units =~ /GB/) {
         $volume_size{$volume} = $value/1000;
      } elsif ($units =~ /TB/) {
         $volume_size{$volume} = $value;
      } else {
         print "ERROR, don't know what units these are ***$units***\n";
         $volume_size{$volume} = 0;
      }

      # There are five statuses for tape %tstatus{$volume}:
      #	(b) Blank and labeled
      #	(u) Blank and unlabeled
      #	(e) Written but expired
      #	(f) Written Full 
      #	(p) Written Partial
      if ( $pused =~ /full/ ) {
         $tstatus{$volume} = 'f';
         $calculated_capacity += $volume_size{$volume};
         if (defined $calculated_capacity_pool{$pool}) {
            $calculated_capacity_pool{$pool} += $volume_size{$volume};
            $number_of_tapes_used_for_capacity_pool{$pool} += 1;
         } else {
            $calculated_capacity_pool{$pool} = $volume_size{$volume};
            $number_of_tapes_used_for_capacity_pool{$pool} = 1;
         }
         $number_of_tapes_used_for_capacity += 1;
      } else {
         if ($volume_size{$volume} < $empty) {
            $tstatus{$volume} = 'b';
         } else {
            $tstatus{$volume} = 'p';
         }
      }
      if ($texpired{$volume} eq 'e') {$volume_size{$volume} = 0};
   }
}

$average_capacity = $calculated_capacity/$number_of_tapes_used_for_capacity;
$out = sprintf ("%5.2f",$average_capacity);
$capacity_txt = $average_capacity*1000;
$capacity_txt = sprintf ("%6.0f",$capacity_txt);
$capacity_txt = "$capacity_txt".'G';
print "\n\n$dash\n";
print "  Calculating the Average Capacity of Full Tapes for the Previous 4 Weeks $out TB\n";
$out = $out / $raw_tape_capacity;
$out = sprintf ("%5.2f",$out);
print "     The Average Compression Ratio of Full Tapes for the Previous 4 Weeks $out\n";
print "$dash\n\n";
$capacity = $average_capacity;
foreach $pool (sort keys %calculated_capacity_pool) {
   $average_capacity_pool{$pool} = $calculated_capacity_pool{$pool}/$number_of_tapes_used_for_capacity_pool{$pool};
   $capacity_txt = $average_capacity_pool{$pool}*1000;
   $capacity_txt = sprintf ("%6.0f",$capacity_txt);
   $capacity_txt =~ s/^\s+//;
   $capacity_txt_pool{$pool} = "$capacity_txt".'G';
}

#******************************************************************************************************
#
# We now know where the tapes are located and whether they are available for use
#
#******************************************************************************************************

#******************************************************************************************************
#
# Determine the current pool usage on the backup server over the last 4 weeks
#
#******************************************************************************************************
print "\n$dash\n";
print " Calculating Average Tape Use on $server for Previous Four Weeks $date\n";;
print "$dash\n\n";
#print "/usr/bin/ssh -q $server /usr/sbin/mminfo -a -s $server -xc, -r \'volume,pool,family\'  -q \'savetime>$weeks weeks ago\'\n";
(@return) = `/usr/bin/ssh -q $server "/usr/sbin/mminfo -a -s $server -xc, -r \'volume,pool,family\'  -q \'savetime>$weeks weeks ago\' | /usr/bin/sort | /usr/bin/uniq  2>&1"`;
undef %pool_space_used;
undef %pool_tapes_used;
$count=0;
foreach $val (@return) {
   next if $val =~ /volume/;
   next if $val =~ /^\s*$/;
   next if $val=~/^Filesystem/;
   next if $val=~/^backup/;

   chomp $val;
   my ($volume,$pool,$family) = split(/,/,$val);
   $volume =~ s/\(R\)//;
   next if $family =~ /disk/; 
   next if $pool =~ /Offsite/;
   next if $pool =~ /Decade/;
   # Want to have exact size by pool might be a little error from tapes partially filled before 4 weeks ago
   $count += 1;
   if (defined $pool_space_used{$pool}) {
      $pool_space_used{$pool} += $volume_size{$volume};
      $pool_tapes_used{$pool} += 1;
   } else {
      $pool_space_used{$pool}  = $volume_size{$volume};
      $pool_tapes_used{$pool}  = 1;
   }
}

# Determine the optimal number of tapes required per week 
$tnextweek = 0;
$tcurrent  = 0;
foreach $val (sort keys %pool_space_used) {
   $pool_space_used{$val}    = $pool_space_used{$val}/$weeks;
   if (defined $minimum_tapes{$val}) {
      if ($pool_space_used{$val} < $minimum_tapes{$val}*$capacity) {$pool_space_used{$val} = $minimum_tapes{$val}*$capacity};
   }
   #print "pool_space_used{$val\}= $pool_space_used{$val}\n";
   $tcurrent  += $pool_space_used{$val};

}
$tnextweek = int($tcurrent*$fudge/$average_capacity +.9);
$tcurrent  = int($tcurrent /$average_capacity + .9);
# This is correct since it takes all the slots subtracts next week and then divides the remainder by the average
$optimal_cycles_in_jukebox = ($slots_per_jukebox - $free_slots - $cleaning_slots - $tnextweek)/$tcurrent +1;
#print "$slots_per_jukebox, $free_slots , $cleaning_slots , $tnextweek), $tcurrent, $optimal_cycles_in_jukebox\n";
$out = sprintf ("%5.2f",$optimal_cycles_in_jukebox);
print "                   Optimum retention in the jukebox = $out weeks\n";
print "                Required Empty Slots in the jukebox = $free_slots\n";
#print "                   Tapes required for the next week = $tnextweek\n";
print "             Current Average Weekly Usage All Pools = $tcurrent\n";

#******************************************************************************************************
#
# Determine which tapes should be ejected based on full, old, and pool required can also determine
#	if there are unlabeled tapes in the jukebox
#
#******************************************************************************************************

(@return) = `/usr/bin/ssh -q $server /usr/sbin/nsrjb -C -v -j $jukebox -s $server 2>&1`;
#setting verbosity level to `1'
#                1:      ADIC_LTO5       [enabled]
#There is only one enabled and configured jukebox: ADIC_LTO5
#
#Jukebox ADIC_LTO5: (Ready to accept commands)
#slot  volume                             used  pool         barcode  volume id        recyclable
#   1: UN4671                             full  SSCNOLALTO5  UN4671   2699959952       no
#   2: UN6070                               0%  SSCNOLALTO5  UN6070   4143156064       no
#   7: UN5595                             full  SSCNOLALTO5  UN5595   3807004662       no
#   8: UN7846                               0%  NATO         UN7846   3065938466       no
#   9: UN6075                               0%  SSCNOLALTO5  UN6075   4109601683       no
# 269: UN6022                               0%  SSCNOLALTO5  UN6022   368195663        no
# 270:
# 271: UN5304                             full  SSCNOLALTO5  UN5304   3168002243       no
# 271: UN5304                             full  SSCNOLALTO5  UN5304   3168002243       no
# 273: UN5306*					                 UN7006  1738229226 
# 295: Cleaning Tape (27 uses left)                                UN6042   -
# 296: Cleaning Tape (26 uses left)                                CLN212   -
# Want to know empty slots per pool
undef @empty_slots;
undef @unlabeled;
undef %slot_for_volume;
undef %jpartial_tapes_pool;
undef %empty_tapes_pool;
undef %tapes_per_pool_jukebox;
foreach $val (@return) {
  next if $val =~ /Cleaning/;
  next if $val =~ /There is only/;
  next if $val =~ /^Jukebox/;
  next if $val =~ /^slot\s+volume/;
  chomp $val;
  # In jukebox want to know empty tapes, full tapes, partial tapes, unlabeled tapes all per pool and empty slots.
  if ($val =~ /^\s+\d+\: /) {	# Found a Slot Number
     ($jslot) = ($val =~ /^\s+(\d+)\:/);
     if ( ($val =~ /^\s+\d+\:\s+\S+\*/) || ($val =~ /\-\*/) ) {		# look for * on tape name meaning only have barcode label
     #if ($val =~ /\-\*/) {		# look for * on tape name meaning only have barcode label
        #print "Found unlabeled $val\n";
        push (@unlabeled,$jslot);
        if ($val =~ /^\s+\d+\:\s+\-\*\s+(\S+)/) {
           ($blank_name) = ($val =~ /^\s+\d+\:\s+\-\*\s+(\S+)/);
        } else {
           ($blank_name) = ($val =~ /^\s+\d+\:\s+(\S+)\*/);
        }
        $unlabeled_slot_to_name{$jslot} = $blank_name;
        if ($blank_name=~ /UNN/) {
           $unlabeled_slot_to_pool{$jslot} = 'NavyNuclear';
        } else {
           $unlabeled_slot_to_pool{$jslot} = 'SSCNOLALTO5';
        }

     } elsif ($val =~ /:\s*$/) {
        next if $jslot > $max_usuable_slot;
        push(@empty_slots,$jslot);
     } elsif ($val =~ /:\s\S+\*/) {
        ($jtape) = ($val =~ /^\s+\d+\:\s+(\S+)\*/);
        if ($val =~ /UNN/) {
           push (@unlabeled,$jslot);
           $unlabeled_slot_to_name{$jslot} = $jtape;
           $unlabeled_slot_to_pool{$jslot} = 'NavyNuclear';
           #print "Jtape=$jtape\n";
	} else {
           $unlabeled_slot_to_name{$jslot} = $jtape;
           $unlabeled_slot_to_pool{$jslot} = 'SSCNOLALTO5';
        }
     } else {
       my ($jtape,$jfull,$jpool,$jbarcode) = ($val =~ /^\s+\d+\:\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+\S+\s+\S+.*$/);
       if (!defined $jtape) {print "$val\n"};
       $jtape =~ s/\(R\)//;
       if ($jfull !~ /full/) {
          $jfull =~ s/%//;
          if ( ($jfull == 0) || ($val =~ /yes\s*$/)) {
             $empty_tapes_pool{$jtape} = $jpool;
             #if ($jpool =~ /AFTDClone/) {print "440 Empty tapes per pool $jtape $empty_tapes_pool{$jtape}\n"};
          } else {
             $jfull = (1 - $jfull/100)*$average_capacity_pool{$jpool};
             $jpartial_tapes_pool{$jtape} = $jpool;
             #if ($jpool =~ /AFTDClone/) {print "445 Partial tapes per pool $jtape $jpartial_tapes_pool{$jtape}, Jfull=$jfull\n"};
          }
       } else {
          $jfull_tapes_pool{$jtape} = $jpool;
          # Only want full tapes
          $jexpiration{$jtape} = $texpiration{$jtape};
       }

       #$tlocation{$tape} = 'j';
       $slot_for_volume{$jtape} = $jslot;
       if ($tapes_per_pool_jukebox{$jpool}) {
          $tapes_per_pool_jukebox{$jpool} += 1;
       } else {
          $tapes_per_pool_jukebox{$jpool} = 1;
       }
     }

  } else {
     if ($val =~ /Default slot range/) {
        $maximum_usable_slot = $val;
        $maximum_usable_slot =~ s/^\s+Default slot range\(s\) are //;
        $maximum_usable_slot =~ s/\d+\-//;
     }
  }
}
# lose the empty spots in the cleaning tape range
#foreach $val (sort keys %empty_tapes_pool) {
#   if ($val > $maximum_usable_slot) { undef $empty_tapes_pool{$val}};
#}

foreach $vbn (keys %tapes_per_pool_jukebox) {
    $count_jpartial_tapes_pool{$vbn}=0;
    $count_empty_tapes_pool{$vbn}=0;
    $count_jfull_tapes_pool{$vbn}=0;
}

foreach $vbn ( sort { $jpartial_tapes_pool{$a} cmp $jpartial_tapes_pool{$b} } keys %jpartial_tapes_pool) {
  $pool = $jpartial_tapes_pool{$vbn};
  $count_jpartial_tapes_pool{$pool} +=1;
  #print "Tape $vbn: Partial :$pool\n";
}
foreach $vbn ( sort { $empty_tapes_pool{$a} cmp $empty_tapes_pool{$b} } keys %empty_tapes_pool) {
  $pool = $empty_tapes_pool{$vbn};
  $count_empty_tapes_pool{$pool} +=1;
  #print "Tape $vbn: Empty :$pool\n";
}
foreach $vbn ( sort { $jfull_tapes_pool{$a} cmp $jfull_tapes_pool{$b} } keys %jfull_tapes_pool) {
  $pool = $jfull_tapes_pool{$vbn};
  $count_jfull_tapes_pool{$pool} += 1;
  #print "Tape $vbn: $count_jfull_tapes_pool{$pool}, Full :$pool\n";
}

# Calculate the number of tapes previously written tepace required 526.496819482414
#maintain in the jukebox to keep up recover time which could mean removing tapes in a pool
print "\n\n$dash\n";
$return = build_output_record(-91,$output,'|  Eject tape to free up slots required for the next backup, not extra pool tapes  |',91,0,-1,-1 ,'',1,91);
print "$return\n";
print "$dash\n\n\n";
print "$dash\n";
$return = build_output_record(-91,$output,'|                  |                        T  A  P  E  S                          |',91,0,-1,-1 ,'',1,91);
print "$return\n";
print "$dash\n";
$return = build_output_record(-91,$output,                 '|Weekly| EMPTY | EXTRA |PARTIAL|  FULL  |OPTIMAL| AVERAGE| COMP |',91,0,-1,-1 ,'',20,91);
print "$return\n";
$return = build_output_record(-91,$output,'POOL NAME          |  Use |   in  |   in  |   in  |   in   |   in  |CAPACITY| RATIO|',91,0,-1,-1 ,'',1,91);
print "$return\n";
$return = build_output_record(-91,$output,              '|4 wks |Jukebox|Jukebox|Jukebox|Jukebox |Jukebox|  (TB)  |      |',91,0,-1,-1 ,'',20,91);
print "$return\n";
# Don't compute number required for ejection until we know how many tapes need to be added
print "$dash\n";
#foreach $val (sort keys %pool_tapes_by_size) {
foreach $val (sort keys %pool_space_used) {
   $space_still_required_per_pool{$val} =  $pool_space_used{$val}*$fudge; 
   $tmaintain{$val}  = int( ( ($optimal_cycles_in_jukebox-1) * $pool_space_used{$val} +  $space_still_required_per_pool{$val})/$average_capacity_pool{$val} + .9);
   # Pool
   $return = build_output_record(-91,$output,$val,15,0,-1,-1,'',1,91);
   # Used tapes per pool
   # Total Tapes used in four weeks
   #$pool_tapes_used{$val} = int($pool_tapes_used{$val}/$weeks + .9);
   $weekly_use = int( $pool_space_used{$val} / $average_capacity_pool{$val} + .9);
   # Need to determine if we have more full tapes than we need
   # Number of full tapes required $tmaintain{$val} - $weekly_use ;
   # How many can be kicked out = $count_jfull_tapes_pool{$val} - ($tmaintain{$val} - $weekly_use)
   $tmax_eject{$val} = $count_jfull_tapes_pool{$val} - ($tmaintain{$val} - $weekly_use);
   #print "pool_space_used\{$val\}=$pool_space_used{$val}, Capacity=$capacity, Weeks=$weeks, Weekly_use=$weekly_use\n";
   $return = build_output_record(0,$output,$weekly_use,5,0,1,1,'comma',21,25);
   # Empty tapes per pool
   $extra_tapes_pool{$val} = $count_empty_tapes_pool{$val} - $weekly_use ;
   $temp = $count_empty_tapes_pool{$val};
   $return = build_output_record(0,$output,$temp,5,0,1,1,'comma',25,32);
   $return = build_output_record(0,$output,$extra_tapes_pool{$val},5,0,1,1,'comma',32,39);
   $temp = $count_jpartial_tapes_pool{$val};
   $return = build_output_record(0,$output,$temp,5,0,1,1,'comma',41,48);
   $temp = $count_jfull_tapes_pool{$val};
   $return = build_output_record(0,$output,$temp,5,0,1,1,'comma',50,57);
   $return = build_output_record(0,$output,$tmaintain{$val},5,0,1,1,'comma',58,66);
   $return = build_output_record(0,$output,$average_capacity_pool{$val},5,2,1,1,'comma',64,74);
   $out = $average_capacity_pool{$val}/ $raw_tape_capacity;
   $return = build_output_record(0,$output,$out,5,2,1,1,'comma',72,82);
   print "$return\n";
} 
$return = build_output_record(-84,$output,'Empty Slots',15,0,-1,-1,'',1,84);
$empty = $#empty_slots+1;    # This includes the 12 slots reserved for recovers
$return = build_output_record(0,$output,$empty,5,0,1,1,'comma',25,32);
$return = build_output_record(0,$output,$free_slots,5,0,1,1,'comma',58,66);
#$temp = $temp - $free_slots;
#$return = build_output_record(0,$output,$temp,5,0,1,1,'comma',75,81);
print "$return\n";
print "$dash\n";
#***********************************************************************************************************
# Shouldn't load tapes unless we are short of the number of tapes we need for a pool 
#	($jukebox_eject_required_pool{$val} < 0
#
# Shouldn't eject tapes unless we need room to load new ones or there are not 12 empty slots
# If we need to eject tapes then choose ones from pools that have more than they should have in the jukebox
#***********************************************************************************************************
$flag = 0;
print "\n";
foreach $val (sort keys %extra_tapes_pool) {
   if ($extra_tapes_pool{$val} < 0) {
      $val1 = -$extra_tapes_pool{$val};
      #print "Need $val1 additional tape(s) for pool $val and may need to eject tapes to make room\n"; 
      $flag+=$val1;
   }
}
if ($flag == 0) {
      print "\n\n**************** All pools have sufficient tapes for the next week  ****************\n";
}
PERCENT: print "\nFor special circumstances, additional tapes can be added to the above. Enter a percent (0-50): ";
$added_percentage = <STDIN>; 
chomp $added_percentage;
if ($added_percentage !~ /^\d+$/) {
   print "\tEnter a number between 0 and 50\n";
   goto PERCENT;
}
if ( ($added_percentage < 0) || ($added_percentage > 250) ) {goto PERCENT};
$added_percentage = 1+ $added_percentage/100;
foreach $pool (sort keys %space_still_required_per_pool) {
   $space_still_required_per_pool{$pool} = $space_still_required_per_pool{$pool}*$added_percentage; 
   #Now compute how many tapes should be ejected from the jukebox to balance out the optimal per pool
   $jukebox_eject_required_pool{$pool} =  ($count_jfull_tapes_pool{$pool} + $space_still_required_per_pool{$pool}/$average_capacity_pool{$pool}) - $tmaintain{$pool}  ;
   #print "707 Space still require per pool \{$pool\}=$space_still_required_per_pool{$pool}, jukebox_eject_required_pool\{$pool\}=$jukebox_eject_required_pool{$pool}\n";
}
#******************************************************************************************************
#
# Now have what is in the jukebox including empty tapes by pool, unlabeled tapes can be used for other pools
#
#*****************************************************************************************************
# Order to use
# 1. Partially filled tapes in the correct pool in the jukebox that were written within the last two months
#	Don't want to use tapes getting ready to recycle.
# 2. Empty tapes in the correct pool in the jukebox
# 3. Blank tapes with correct label in the jukebox (might be better if these are previously labeled)
# 4. Partially filled tapes in the correct pool on the correct server in the tape library
# 5. Recycled tapes in the correct pool on the correct server in the tape library
# 6. Recycled tapes in the correct range in the tape library on the alternate server (To balance tapes between backup servers)

undef %gonna_use;
undef %need_to_load;
undef %need_to_label;
undef %tapes_to_delete_on_alternate;
#print "Before space required $space_still_required_per_pool{$pool}\n";
$iicount = 0;
foreach $pool (sort keys %space_still_required_per_pool) {
   #print "\nNeed $space_still_required_per_pool{$pool} on server $server for pool $pool\n";
   next if $space_still_required_per_pool{$pool} < 0;
   foreach $tape (sort keys %jpartial_tapes_pool) {		#This will sort by lowest to highest tape
      last if $space_still_required_per_pool{$pool} <=0;
      next if defined $gonna_use{$tape};

      # Partially filled tapes in the correct pool in the jukebox
      if ($jpartial_tapes_pool{$tape} eq $pool) {
          # Found empty partially filled tape in the pool
          $iicount += 1;
          $gonna_use{$tape} = $pool;
          $space_still_required_per_pool{$pool} -= ($average_capacity_pool{$pool} - $volume_size{$tape});
      }
   } 

   if ($space_still_required_per_pool{$pool} <= 0) {
      print "\n\tRecovered enough space using partially filled $pool tapes in jukebox\n";
      next;
   }

   # Empty tapes in the correct pool in the jukebox
   foreach $tape (sort keys %empty_tapes_pool) {		#This will sort by lowest to highest tape
      last if $space_still_required_per_pool{$pool} <=0;
      next if defined $gonna_use{$tape};

      # Empty tapes in the correct pool in the jukebox
      if ($empty_tapes_pool{$tape} eq $pool) {
         # Found empty tape in the pool
         $iicount += 1;
         $gonna_use{$tape} = $pool;
         $space_still_required_per_pool{$pool} -= $average_capacity_pool{$pool};
         last if $space_still_required_per_pool{$pool} <= 0;
         #print "630 ,$iicount,Empty tape=$tape, space_still_required_per_pool\{$pool\}=$space_still_required_per_pool{$pool}\n";
      }
      
   } 

   #if ($space_still_required_per_pool{$pool} <= 0) {
   #   print "\n\tRecovered enough space using empty tapes for pool $pool currently in jukebox\n";
   #   next;
   #}

   #print "\n\tLooking for Unlabeled tapes in jukebox for $pool server $server still needing $space_still_required_per_pool{$pool}\n";

   # Unlabeled tapes with correct label in the jukebox (might be better if these are previously labeled)
   # Print report to label into correct pool
   #print "********** Number of unlabeled tapes=$#unlabeled\n";
   foreach $slot (@unlabeled) {		#This will sort by lowest to highest slot
      #print "769 , unlabeled_slot_to_name{$slot}=$unlabeled_slot_to_name{$slot}, $unlabeled_slot_to_pool{$slot}\n";
      if ($unlabeled_slot_to_pool{$slot} eq $pool) {
         #next if defined $gonna_use{$unlabeled_slot_to_name{$slot}};
         $iicount += 1;
         $gonna_use{$unlabeled_slot_to_name{$slot}} = $pool;
         #print "647 , $iicount, unlabeled_slot_to_name{$slot}=$unlabeled_slot_to_name{$slot}, $pool\n";
         $space_still_required_per_pool{$pool} -=  $average_capacity_pool{$pool}; 
         $need_to_label{$unlabeled_slot_to_name{$slot}} = $pool;
         last if $space_still_required_per_pool{$pool} <=0;
      }
   }
   #print "After Unlabeled tapes for pool $pool\n";   
   if ($space_still_required_per_pool{$pool} <= 0) {
      print "\n\tFound enough unlabeled tapes in jukebox for pool $pool\n";
      next;
   }

   # Expired tapes in the jukebox
   #print "\n\tLooking for $pool expired tapes in the jukebox server $server to meet $space_still_required_per_pool{$pool} space\n";
   foreach $jtape (sort keys %jexpiration) {
      if ($jexpiration{$jtape} < $now) {
         #print "\n\t$jexpiration{$jtape}, Tape=$jtape, Now=$now\n";
         #print "Jtape in expired=$jtape\n";
         $jjpp = $jfull_tapes_pool{$jtape};
         if ($jjpp =~ /NavyNulear/) {
            if ($jtape =~ /UNN/) {
               $jjpp = 'NavyNuclear';
            } else {
               $jjpp = 'SSCNOLALTO5';
            }
         }

         if ($jjpp =~ $pool) {
            #if ($jtape =~ /UNN/) {
               #print "Found an expired tape in the jukebox $jtape, for pool $pool\n";
               $iicount += 1;
               $gonna_use{$jtape} = $pool;
               $space_still_required_per_pool{$pool} -=  $average_capacity_pool{$pool};
               $need_to_label{$jtape} = $pool;
               #last if $space_still_required_per_pool{$pool} <=0;    # Want to use all tapes in jukebox even if more than we need
            #}
         } 
      }     

    }

   #print "\n\tLooking for $pool partially filled tapes in the tape library  server $server to meet $space_still_required_per_pool{$pool} space\n";

   #print "Space still required per pool before partial = $space_still_required_per_pool{'SSCNOLALTO5'}\n";
   # Partially filled tapes in the correct pool on the correct server in the tape library
   foreach $volume (sort keys %tlocation) { 
      if ($tserver{$volume} eq $server) {
         if ($tlocation{$volume} eq 'l') {
            # Tape is in the library 
            if ($tstatus{$volume} eq 'p'  || $tstatus{$volume} eq 'b' ) {
               # Tape is partially filled or empty
               if ($tpool{$volume} eq $pool) {
                  # Tape is in the correct pool
                  # does the tape expire within the next three months
                  #print "841 volume=$volume, now=$now, texpiration\{$volume\} = $texpiration{$volume}\n";
                  $last_written = $texpiration{$volume} - $now;
                  # If the tape has expired then it can be used
                  if ($last_written > 7776000) {
                     next if $space_still_required_per_pool{$pool} < 0;
                     #print "Partially filled tapes in the correct pool on the correct server $volume\n";
                     $iicount += 1;
                     $gonna_use{$volume} = $pool;
                     $need_to_load{$volume} = $pool;
                     $space_still_required_per_pool{$pool} -= ($average_capacity_pool{$pool} - $volume_size{$volume});
                     #print "677,$iicount, Partially filled in tape library  tape=$volume, space_still_required_per_pool\{$pool\}=$space_still_required_per_pool{$pool}\n";
                     last if $space_still_required_per_pool{$pool} < 0;
                  }
               }
            }
         }
      }
   }

   if ($space_still_required_per_pool{$pool} <= 0) {
      print "\n\tFound enough partially filled $pool tapes on the shelves in tape library\n";
      next;
   }

   #print "\n\tLooking for expired  $pool tapes in the tape library. Still need $space_still_required_per_pool{$pool} space\n";
   # Recycled tapes in the correct pool on the correct server in the tape library
   foreach $volume (sort keys %texpired) { 
      #foreach $volume (sort keys %tlocation) { 
      #print "Volume $volume and location $tlocation{$volume}\n";
      if ($tserver{$volume} eq $server) {
         if ($tlocation{$volume} eq 'l') {
            # Tape is in the library 
            if ($texpired{$volume} eq 'f') {	# Written but expired, make sure this is updated
               #print "Volume=$volume expired =$texpired{$volume}\n";
               # Tape is expired
               # Could have tapes formally in different pools but only thing important is tape label
               # Move expired AFTDCLONE, NATO
               if ($pool =~ /SSCNOLALTO5/) {
                  # Pools that can be used SSCNOLALTO5, AFTDCLONE, NATO
                  if ($volume =~ /UN\d\d\d\d/) {
                     #print "Filled tapes in the correct pool on the correct server $volume\n";
                     # Tape is in the correct pool
                     $iicount += 1;
                     $gonna_use{$volume} = $pool;
                     $need_to_load{$volume} = $pool;
                     $need_to_label{$volume} = $pool;
                     $space_still_required_per_pool{$pool} -= $average_capacity_pool{$pool};
                     #last if $space_still_required_per_pool{$pool} < 0;
                     if ($space_still_required_per_pool{$pool} < 0) {goto EXPIRED};
                  }
               } elsif ($tpool{$volume} eq $pool) {
                  #print "Filled tapes in the correct pool on the correct server $volume\n";
                  # Tape is in the correct pool
                  $iicount += 1;
                  $gonna_use{$volume} = $pool;
                  $need_to_load{$volume} = $pool;
                  $need_to_label{$volume} = $pool;
                  $space_still_required_per_pool{$pool} -= $average_capacity_pool{$pool};
                  #print "746,$iicount, Expired tapes in tape library  tape=$volume, space_still_required_per_pool\{$pool\}=$space_still_required_per_pool{$pool}\n";
                  #last if $space_still_required_per_pool{$pool} < 0 ;
                  if ($space_still_required_per_pool{$pool} < 0) {goto EXPIRED};
               }
            }
         }
      }
   }
   EXPIRED:

   if ($space_still_required_per_pool{$pool} <= 0) {
      #print "\n\tFound enough expired $pool tapes on the shelves in the tape library\n";
      next;
   }

   #print "\n\tLooking for Empty $pool tapes in the library required to meet $space_still_required_per_pool{$pool} more space\n";

   # Empty tapes in the correct pool on the correct server in the tape library
   foreach $volume (sort keys %tlocation) { 
      if ($tserver{$volume} eq $server) {
         if ($tlocation{$volume} eq 'l') {
            # Tape is in the library 
            if ($tstatus{$volume} eq 'b' ) {
               # Tape is empty
               if ($tpool{$volume} eq $pool) {
                  # Tape is in the correct pool
                  #print "Empty tapes in the correct pool on the correct server $volume\n";
                  $iicount += 1;
                  $gonna_use{$volume} = $pool;
                  $need_to_load{$volume} = $pool;
                  $space_still_required_per_pool{$pool} -= ($average_capacity_pool{$pool} - $volume_size{$volume});
                  #print "708,$iicount, Empty tapes in tape library  tape=$volume, space_still_required_per_pool\{$pool\}=$space_still_required_per_pool{$pool}\n";
                  last if $space_still_required_per_pool{$pool} < 0;
               }
            }
         }
      }
   }

   if ($space_still_required_per_pool{$pool} <= 0) {
      #print "\n\tFound enough empty $pool tapes on the shelves in the tape library\n";
      next;
   }


   # No alternate server 
   #next if $alternate =~ '';

   #print "\n\tLooking on the alternate server $alternate for recycled tape in pool $pool for $space_still_required_per_pool{$pool} space\n";

   # Recycled tapes in the correct range in the tape library on the alternate server (To balance tapes between backup servers)
   foreach $volume (sort keys %tlocation) { 
      if ($tserver{$volume} eq $alternate) {
         if ($tlocation{$volume} eq 'm') {
            # Tape is in the library 
            if ($texpired{$volume} eq 'e') {	# Written but expired, make sure this is updated
               # Tape is expired
               # Don't care about pool only care whether in Navy Nuclear
               if ( $pool =~ /NavyNuclear/) {
                  if ($volume =~ /UNN/) {
                     # Tape is in the NavyNuclear pool
                     $iicount += 1;
                     $gonna_use{$volume} = $pool;
                     $need_to_load{$volume} = $pool;
                     $need_to_label{$volume} = $pool;
                     $space_still_required_per_pool{$pool} -= $average_capacity_pool{$pool};
                     $tapes_to_delete_on_alternate{$volume} = $pool;
                     #print "788,$iicount, alternate tapes NN in tape library  tape=$volume, space_still_required_per_pool\{$pool\}=$space_still_required_per_pool{$pool}\n";

                     last if $space_still_required_per_pool{$pool} < 0;
                  }
               } else {
                  # Need check to make sure it is in correct range
                  $test = $volume;
                  $test =~ s/UN//;
                  # Put in checks to see if tapes already moved to primary server
                  if ($test =~ /^[$tester]/) {
                     #next if $test > $upper_tape_range;
                     $gonna_use{$volume} = $pool;
                     $need_to_load{$volume} = $pool;
                     $need_to_label{$volume} = $pool;
                     $space_still_required_per_pool{$pool} -= $average_capacity_pool{$pool};
                     $tapes_to_delete_on_alternate{$volume} = $pool;
                     #print "806,$iicount, alternate tapes in tape library  tape=$volume, space_still_required_per_pool\{$pool\}=$space_still_required_per_pool{$pool}\n";
                     last if $space_still_required_per_pool{$pool} < 0;
                  }
               } 
            }
         }
      }
   }

   if ($space_still_required_per_pool{$pool} <= 0) {
      #print "\n\tFound enough expired $pool tapes on the shelves from the other $alternate server\n";
      next;
   }
   print "\n\n*********************************************************************************************\n";
   print "*********************************************************************************************\n";
       print "\n   Could not find enough tape to load for $pool, add unused tapes into the library   \n";
       $ppp = sprintf("%7.2f",$space_still_required_per_pool{$pool});
       print "   Didn't recover enough tape Space and still require$ppp TB for the $pool pool   \n\n";
   print "*********************************************************************************************\n";
   print "*********************************************************************************************\n\n";
}

#******************************************************************************************************
#
# Can now output the list of tapes required for the next week's backups 
#
#*****************************************************************************************************

$across = 7;
(@print_list) = (sort keys %gonna_use);
$count = $#print_list +1;
print "\n\n$dash\n";
print "The following tapes will be used for this weeks backups ($count)\n";
print "$dash\n";
$pass = '';
$rr = print_column ($pass,$count,$across,@print_list);

undef %eject_pool_count;
# Take care of adding tapes that need to be ejected to balance pools in jukebox 
# Short term this will kick out full tapes, best option would be to relabel empty tapes into other pools
#foreach $pool (sort keys %jukebox_eject_required_pool) { 
#   print "1035 eject_pool_count\{$pool\}=$eject_pool_count{$pool},jukebox_eject_required_pool\{$pool\}=$jukebox_eject_required_pool{$pool}\n";
#   if ($jukebox_eject_required_pool{$pool} > 0) {
#      $eject_pool_count{$pool} = $jukebox_eject_required_pool{$pool};
#   } else {
#      $eject_pool_count{$pool} = 0;
#   }
#}
if (%need_to_load) {
   (@print_list) = (sort keys %need_to_load);
   $count = $#print_list +1;
   $needed_free_slots = $count;
   $pass = "\n\n$dash\nTapes that need to be loaded for this week's backups ($count)\n$dash\n";
   print $pass;
   
   $rr = print_column ($pass,$count,$across,@print_list);
} else {
   print "\n\n$dash\n";
   $needed_free_slots = 0;
   print "There are enough tapes in the jukebox for this week's backups\n";
   print "$dash\n";
}

if (%need_to_label) {
   (@print_list) = (sort keys %need_to_label);
   $count = $#print_list +1;
   print "\n\n$dash\n";
   print "The following tapes will need to be labeled ($count)\n";
   print "$dash\n";
   $pass = '';
   $rr = print_column ($pass,$count,$across,@print_list);
   #print "$dash\n";
} else {
   print "\n$dash\nNo tapes require labeling\n$dash\n\n";
}

#******************************************************************************************************
#
# Now need to figure how many old full tapes need to be ejected
#
#******************************************************************************************************

# Determine how many tapes need to be loaded for each pool, which can to used to determine the full tapes to be ejected
foreach $pool (sort keys %jukebox_eject_required_pool) { 
      $eject_pool_count{$pool} += $jukebox_eject_required_pool{$pool};
      #print "****************$pool eject_pool_count=$eject_pool_count{$pool}, jukebox_eject_required_pool=$jukebox_eject_required_pool{$pool}\n";
}
foreach $tape (sort keys %need_to_load) {
   $pool = $need_to_load{$tape};
   $eject_pool_count{$pool} +=1;
}
undef %eject_lista;
#print "Above need to eject by pool\n";

################ Eject will be used to balance out the slots in the jukebox
# If we need to load exceeds empty slots we need to eject
# $free_slots number we keep free (12), $needed_free_slots is the number we need for loading, $empty is no tape in jukebox slot
$really_need_slots = ($free_slots + $needed_free_slots) -$empty;
#print "Really_need_slots=$really_need_slots, Free_slots =$free_slots, Needed_free_slots=$needed_free_slots\n";
if ($really_need_slots > 0) {
   foreach $volume ( sort { $jexpiration{$a} <=> $jexpiration{$b} } keys %jexpiration) {
      next if $gonna_use{$volume}; 
      if (defined $jfull_tapes_pool{$volume} ) {
         if ($jexpiration{$volume} < $year_ago) {print "Jexpiration < $year_ago\n"};
         $test = $tpool{$volume};
         if ( $tmax_eject{$test} > 0) {
            $tmax_eject{$test} -= 1;
            $really_need_slots -=1;
            $eject_lista{$volume} = 1;
            if ($really_need_slots < 1) {goto GOTENOUGH};
         }
      }
   }
   # Get remaining tapes out of SSCNOLALTO5
   foreach $volume ( sort { $jexpiration{$a} <=> $jexpiration{$b} } keys %jexpiration) {
      next if $eject_lista{$volume};
      next if $gonna_use{$volume}; 
      next if $jexpiration{$volume} < $year_ago;
      $test = $tpool{$volume};
      if ($test =~ /SSCNOLALTO5/) {
         #print "Found volume Pool=$test, Volume=$volume, Expiration=$jexpiration{$volume}\n";
         $eject_lista{$volume} = 1;
         $really_need_slots -= 1;
      }
      if ($really_need_slots < 1) {goto GOTENOUGH};
   }
   print "*** E R R O R:  Could not find enough tapes to eject\n";
   exit;
}
GOTENOUGH: @eject_list = sort keys %eject_lista;
$count = $#eject_list +1;
if ($count > 0) {
   $pass = "\n$dash\nThe following tapes will be ejected ($count)\n$dash\n";
   print $pass;
   #@eject_list = sort @eject_list;
   $rr = print_column ($pass,$count,$across,@eject_list);

   #****************************************************************************************************
   # Eject Code Here
   #****************************************************************************************************
   my $sreturn;
   # Compute number of open slots required
   # Need to load 

#****************************************************************************************************
#***************************************  E J E C T  T A P E  ***************************************
#****************************************************************************************************
   $sreturn = eject_tapes($count,@eject_list);
   # Know what slots were ejected and are now frre
   # Take an inventory to determine all empty slots and another after tapes injested
} else {
   $pass = "\n$dash\nThere are enough free slots, no tapes need be ejected\n$dash\n\n";
   print $pass;
}
#****************************************************************************************************
#****************************************  L O A D  T A P E  ****************************************
#****************************************************************************************************
if (%need_to_load) {$return = load_tapes(%need_to_load)};

#****************************************************************************************************
#***************************************  L A B E L  T A P E  ***************************************
#****************************************************************************************************
if (%need_to_label) {
	#$sreturn = label_tapes(%need_to_label)};
	$how_many_streams = 5;
        $tape_label_file = "/home/scriptid/scripts/BACKUPS/LABELING/tape_list_$date";
        open (TAPE_LIST,">$tape_label_file") or die "Could not open $tape_label_file\n";
        foreach $volume (sort keys %need_to_label) {
           $slot = which_slot($volume,$jukebox);
           if ($slot == 9999) {
              print "\n\nERROR: Tape $volume was not loaded into the jukebox\n";
              next;
           }
           if (defined $tpool{$volume}) {
              if ($tpool{$volume} =~ /^\s*$/) {
                 $ppool = 'SSCNOLALTO5';
              } else {
                 $ppool = $tpool{$volume};
              }
           } else {
              $ppool = 'SSCNOLALTO5';
           }
           if ($volume =~ /^UNN/) {$ppool = 'NavyNuclear'};
           if ($ppool =~ /^SSCNOLA2/) {$ppool = 'SSCNOLALTO5'};
           if ($ppool =~ /^$/) {$ppool = 'SSCNOLALTO5'};
           #print "$volume,$server,$alternate,$ppool,$slot,$capacity_txt_pool{$ppool},$jukebox,$date\n";
           print TAPE_LIST "$volume,$server,$alternate,$ppool,$slot,$capacity_txt_pool{$ppool},$jukebox,$date\n";
        }
        close TAPE_LIST;
        $i=0;
	while ($i<$how_many_streams) {
	    ++$i;
	    print "Starting label stream $i\n";
	    print "/n/nStarting tape process thread $date $i\n";
	    my $ret = system("/usr/bin/ssh -q $server /home/scriptid/scripts/BACKUPS/process_tape_label_list.pl $date $i &");
	    sleep 5;
	}

}


###########################################################################################################

sub eject_tapes {
    my ($count,@volumes) = @_;
    my @remove = @volumes;
    print "\n\nPlease empty the mailslots we will eject $count tapes, $mailslots at a time\n";
    YESORNO:
    print "Are the mailslots empty (Y or N): ";
    $iyorn = <STDIN>;
    chomp $iyorn;
    $iyorn = lc $iyorn;
    if ($iyorn =~ /n/) {go to YESORNO};
   # foreach ($i=0;$i<$count;$i+=1) {
   #    $volume = shift(@remove);
   #    $port +=1;
   #    #print "/usr/sbin/nsrjb -w -s $server -P $port $volume\n";
   #    @evol = 
   #    TRYAGAIN: $return = `/usr/bin/ssh -q $server /usr/sbin/nsrjb -w -s $server -P $port $volume 2>&1 `;
   #    if ($return =~ /failed to withdraw/) {
   #       print "ERROR: returned from jukebox $return\n";
   #       print "ERROR: ******* Mail Slot $port is not empty ************\n";
   #       print "Please empty mailslots $port->$mailslots\n";
   #       print "When mailslots $port->$mailslots are empty, hit anything to continue: ";
   #       $iyorn = <STDIN>;
   #       goto TRYAGAIN;
   #    };
   $current = 1;
   EMORE: 
   $end     = $current + $mailslots -1;
   if ($end > $count) {$end=$count};
   $start = $current -1;
   $last  = $end -1;
   # Eject multiple tapes at a time to speed up process
   @evol = @volumes[$start..$last];
   $return = `/usr/bin/ssh -q $server /usr/sbin/nsrjb -w -s $server @evol 2>&1 `;
   print "Return=$return\n";
   if ($end < $count ) {
      print "\n\nPlease empty all the mailslots, anything when ready";
      $iyorn = <STDIN>;
      $current = $end + 1;
      goto EMORE;
   }
}

sub load_tapes {
   my (%volumes) = @_;
   $count = (keys %volumes);
   my $ret = empty_jslots($jukebox);
   #foreach $val (sort keys %empty_slot_in_jukebox) {
   #   print "Empty slot = $val\n";
   #}
   #$tapes_per_jslot($jukebox);

   # It is faster to load whole mailslots than individual tapes
   print "\n\nWe need to load $count tapes\n";
   my $yesno = "Y`\n'N";
   my $passes = int($count/$mailslots+.9);
   print "Will require $passes passes\n";
   foreach ($i=1;$i<=$passes;$i+=1) {
      $number = $i * $mailslots;
      $load_number = 24;
      if ($number > $count) { $load_number = $count - ($i-1)*$mailslots };
      print "\n\nPass $i, please insert $load_number tapes into the mailslots\n";

      YESORNO:
      print "Are the mailslots loaded and did the jukebox click (Y or N): ";
      $iyorn = <STDIN>;
      chomp $iyorn;
      $iyorn = lc $iyorn;
      if ($iyorn =~ /n/) {go to YESORNO};
      print "/usr/sbin/nsrjb  -d -s $server\n";
      ##print "/usr/bin/echo $yesno  | /usr/sbin/nsrjb  -d -s $server 2>&1\n"; 
      # need to fix this 
      $return = `/usr/bin/ssh -q $server "/usr/bin/cat /home/scriptid/scripts/BACKUPS/abc | /usr/sbin/nsrjb -d -s $server 2>&1" `;
      print "Return=$return\n"; 
   }
}

sub label_tapes {
   # It is faster to load whole mailslots than individual tapes
   my (%volumes) = @_;
   foreach $volume (sort keys %volumes) {
      # Delete the tape
      $dserver = $server;
      if ($tlocation{$volume} eq 'm') {$dserver = $alternate};
      print "/usr/sbin/nsrmm -s $dserver -d -y -v $volume\n";
      $return = `/usr/bin/ssh -q $server /usr/sbin/nsrmm -s $server -d -y -v $volume`;
      print "Return from deleting tape $volume, $return";
      if ($! !~ /Illegal seek/) {
         print ", $!\n";
      }elsif ($! =~ /not in the media index/) {
         print "Doesn't require deletion from media index\n";
      } else {
         print "\n";
      }

      # Delete the tape on the remote server that it is being transferred from
      if (defined $tapes_to_delete_on_alternate{$volume}) {
         # Delete the tape
         print "/usr/bin/ssh -q $server /usr/sbin/nsrmm -s $alternate -d -y -v $volume\n";
         $return = `/usr/bin/ssh -q $server /usr/sbin/nsrmm -s $alternate -d -y -v $volume`;
         print "Return from deleting tape $volume on remote server $alternate, $return";
         if ($! !~ /Illegal seek/) {
            print ", $!\n";
         }elsif ($! =~ /not in the media index/) {
            print "Doesn't require deletion from media index\n";
         } else {
            print "\n";
         }
      }

      # Label the tape
      #print "In label Volume=$volume, Jukebox=$jukebox\n";
      $slot = which_slot($volume,$jukebox);
      #print "Volume=$volume, Jukebox=$jukebox, Slot=$slot, Pool=$tpool{$volume}\n";
      if (defined $tpool{$volume}) {
         $ppool = $tpool{$volume};
      } else {
         $ppool = 'SSCNOLALTO5';
      }
      if ($volume =~ /^UNN/) {$ppool = 'NavyNuclear'};
      print "/usr/bin/ssh -q $server /usr/sbin/nsrjb  -L -c $capacity_txt_pool{$ppool} -s $server -S $slot -Y -j $jukebox -b $ppool $volume\n";
      $return=`/usr/bin/ssh -q $server /usr/sbin/nsrjb  -L -c $capacity_txt_pool{$ppool} -s $server -S $slot -Y -j $jukebox -b $ppool $volume`;
      print "Return from labeling tape $volume, $return";
      if ($! !~ /Illegal seek/) {
         print ", $!\n";
      } else {
         print "\n";
      }
   }
}

sub empty_jslots {
   ($jukebox) = @_;
   (@save_juke) = `/usr/bin/ssh -q $server /usr/sbin/nsrjb -C -j $jukebox -s $server 2>&1`;
   undef %empty_slot_in_jukebox;
   foreach $_ (@save_juke) {
     if ($_ =~ /^\n/) {next};
     if ($_ =~ /Jukebox/) {next};
     if ($_ =~ /slot/) {next};
     chomp $_;
     if ($_ =~ /^\s+\d+\:\s*$/ ) {
        ($slot) = ($_ =~ /\s+(\d+)\:\s*$/); 
        #print "Empty slot = $slot\n";
        $empty_slot_in_jukebox{$slot}=1;
     }
   }
}

#sub tapes_per_jslot {
#   ($jukebox) = @_;
#   (@save_juke) = `/usr/sbin/nsrjb -C -j $jukebox -s $server 2>&1`;
#   foreach $_ (@save_juke) {
#     if ($_ =~ /^\n/) {next};
#     if ($_ =~ /Jukebox/) {next};
#     if ($_ =~ /slot/) {next};
#     chomp $_;
#     if ($_ =~ /^\s+\d+\:\s*$/ ) {
#        ($slot) = ($_ =~ /\s+(\d+)\:\s*$/); 
#        $volume = '';
#     } else {   
#        ($slot,$volume) = ( $_ =~ /^\s+(\d+)\:\s+(\S\S\S\S\S\S)/ );
#     }
#     $slot_per_tape{$volume} = $slot;
#     last if $slot>= $max_usuable_slot;
#     
#   }
#}

sub which_slot {
   ($volume,$jukebox) = @_;
   (@save_juke) = `/usr/bin/ssh -q $server /usr/sbin/nsrjb  -C -j $jukebox`;
   $slot =9999;
   foreach $_ (@save_juke) {
     #print "return from nsrjb $_";
     if ($_ =~ /^\n/) {next};
     if ($_ =~ /Jukebox/) {next};
     if ($_ =~ /slot/) {next};
     chomp $_;
     if ($_ =~ /$volume/ ) {
        ($slot) = ($_ =~ /\s+(\d+)\:/); 
        #print "In which_slot slot=$slot\n";
        goto RET;
     }
   }
RET:
   $return = $slot;
}

sub print_column {
   my ($pass,$limit,$across,@array) = @_;
   if ($pass ne '') {undef @printer_output};
   # $to_printer=0 no printed output
   #             1 send to print file
   #print "Limit=$limit, Across=$across, Number=$#array\n";
   my $how_many_lines = int( $limit/$across);
   my ($line,$i,$j,$array_index);
   if ($how_many_lines*$across < $limit) {$how_many_lines+=1};
   for ($i=0; $i<$how_many_lines; $i+=1) {
      $line = '';
      for ($j=0; $j<$across; $j+=1) {
         $array_index = $i + $j*$how_many_lines;
         if (defined $array[$array_index]) {
            if ($array_index >=  $limit) {goto PRINTER};
            #$print_pool = $tpool{$array[$array_index]};
            #$print_pool =~ m/^\s*(.).*$/;
            if (defined $tpool{$array[$array_index]} ) {
               $print_pool = substr($tpool{$array[$array_index]},0,1);
               #($print_pool) = ($tpool{$array[$array_index]} =~ /^\S/);
            } else {
               $print_pool = ' ';
            } 
            $line = "$line  $array[$array_index]\($print_pool\)";
         } else {
            goto PRINTER;
         } 
      }
      PRINTER: print "$line\n";
      if ($pass  ne '' ) { push (@printer_output,"$line") };
   }
   if ($pass ne '') {
      $pass = $pass . join ("\n",@printer_output);
      $return = `/usr/bin/echo "$pass\n" | /usr/bin/a2ps -E  -r --line-numbers=1 --sides=duplex -f11 --columns=1 -P $default_printer`;
   }
}

