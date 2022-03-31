#!/usr/bin/perl -w
# Process remainder of ssids on tapes
#use Time::Local;
# Set up expire time check for when we converted to a 1 year retention
#$time_5_19_2010= timelocal{0,0,0,19,4,110);
my ($volume,$volid);
my ($complete)="123456";
my $max_tapes_at_a_time=70; # addional tapes
$noinput=0;
$inpjuke='D';
$howmuch=2;
# Retention time
$number_of_days=365;
# Looking at the volretent (Last saveset expiration time)
# If we want to cut into retention time one month, we want to look for tapes with volretent<next month
# Volretent of one year would be volretent<today

if (!defined $ARGV[0]) {
   $ARGV[0]='NO';
   $noinput=1;
} elsif ($ARGV[0] eq 'NO') {
   $site='NO';
   $backup_server='sscprodeng';
   (@jukeboxes) = ('ADIC', 'ADIC_LTO5');
} elsif ($ARGV[0] eq 'SD') {
   $site='SD';
   $backup_server='sdprodeng';
   (@jukeboxes) = ('ADIC-SD');
} elsif ($ARGV[0] =~ /\s+$/) {
   $noinput=1;
} else {
   print "Site incorrectly defined (NO or SD)\n";
   exit;
}

if ($noinput==1) {
  SITE: 
   print "New Orleans (NO) or San Diego (SD)\n";
   $siteinp = <STDIN>;
   if ($siteinp =~ /NO/ ) {
      $site='NO';
      $backup_server='sscprodeng';
      (@jukeboxes) = ('ADIC','ADIC_LTO5');
   } elsif ($siteinp =~ /SD/) {
      $site='SD';
      $backup_server='sdprodeng';
      (@jukeboxes) = ('ADIC-SD');
   } else {
      print "Enter NO or SD\n";
      goto SITE;
   }
  JUKEBOX:
   print "\nWhich jukebox (A) $jukeboxes[0], (B) $jukeboxes[1], (C) All\n";
   $inpjuke = <STDIN>;
   if ($inpjuke =~ /^\s+$/) { 
      $inpjuke='D';
   } else {
      chop $inpjuke;
   }
}

if ($inpjuke eq 'A') {  
   (@jukeboxes) = ($jukeboxes[0]);
} elsif ($inpjuke eq 'B') {  
   (@jukeboxes) = ($jukeboxes[1]);
} elsif ($inpjuke eq 'C') {
   # Keep All
} else {
   print "\nMust enter an 'A', 'B',  or 'C'\n";
   goto JUKEBOX;
}

$wday = (localtime)[6];
#print "Wday=$wday\n";
print "\n*******************************************************************************************\n";
print "The assumption is that the CDL's will backup 3TB/night and 16TB on the weekend\n";
print "The ADIC needs 3TB free in pool SSCNCLN during the week and 16TB in SscnolaADIC on weekends\n";
print "If it is Friday or Saturday the program will free up the tapes required for the weekend\n";
print "*******************************************************************************************\n";

#print "\nCommands to delete and label tapes will be written to /tmp/label.sh\n";
#open (SAVETAPES,">/tmp/label.sh") or die "Could not open file /tmp/label.sh\n";

foreach $jukebox (@jukeboxes) {
        $failures=0;
        undef %bytime;
        # Used to free up SSCNOLA_ADIC Tapes
	if ($jukebox =~ /ADIC_LTO5/) {
           $jukebox='ADIC';
           $THRESHHOLD = '100GB';
           $delta = 24*3600*$number_of_days;
           $capacity='2400GB';
           if ($wday < 5) {
              # 2400 gigabytes/tape 4TB required per night 
              if ($site =~ /NO/ ) {
                 $QPOOL = 'SscnolaADIC';
                 $SPOOL = 'SscnolaADIC';
                 $DPOOL = 'SscnolaADIC';
                 $NUMBER_OF_TAPES_NEEDED=2;
              } else {
                 $QPOOL = 'SscsdADIC';
                 $SPOOL = 'SscsdADIC';
                 $DPOOL = 'SscsdADIC';
                 $NUMBER_OF_TAPES_NEEDED=2;
              }

           } else {
              # 2400gigabytes/tape 30.0 TB required for the weekend
              if ($site =~ /NO/ ) {
                 $NUMBER_OF_TAPES_NEEDED=24;
                 $QPOOL = 'SscnolaADIC';
                 $SPOOL = 'SscnolaADIC';
                 $DPOOL = 'SscnolaADIC';
              } else {
                 $NUMBER_OF_TAPES_NEEDED=20;
                 $QPOOL = 'SscsdAdic';
                 $SPOOL = 'SscsdAdic';
                 $DPOOL = 'SscsdAdic';
              }
           }


	} elsif ($jukebox =~ /ADIC/) {
           $THRESHHOLD = '100GB';
           $delta = 24*3600*$number_of_days;
           $capacity='800GB';
           if ($wday < 5) {
              # 800gigabytes/tape 5TB required per night 
              if ($site =~ /NO/ ) {
                 $QPOOL = 'SscnolaADIC';
                 $SPOOL = 'SscnolaADIC';
                 $DPOOL = 'SscnolaADIC';
                 $NUMBER_OF_TAPES_NEEDED=10;
              } else {
                 $QPOOL = 'SscsdADIC';
                 $SPOOL = 'SscsdADIC';
                 $DPOOL = 'SscsdADIC';
                 $NUMBER_OF_TAPES_NEEDED=5;
              }

           } else {
              # 800gigabytes/tape 30.0 TB required for the weekend
              if ($site =~ /NO/ ) {
                 $NUMBER_OF_TAPES_NEEDED=70;
                 $QPOOL = 'SscnolaADIC';
                 $SPOOL = 'SscnolaADIC';
                 $DPOOL = 'SscnolaADIC';
              } else {
                 $NUMBER_OF_TAPES_NEEDED=60;
                 $QPOOL = 'SscsdADIC';
                 $SPOOL = 'SscsdADIC';
                 $DPOOL = 'SscsdADIC';
              }
           }
        }

        #$NUMBER_OF_TAPES_NEEDED = int($NUMBER_OF_TAPES_NEEDED * $howmuch + .5);
        #print "\nWill need $NUMBER_OF_TAPES_NEEDED tapes\n";
        # Sort and uniq take care of tapes that are expired
        print "/usr/sbin/mminfo  -r volume -q '!full,written<$THRESHHOLD,location=$jukebox,pool=$QPOOL'\n";
        $number_of_tapes_available = `/usr/sbin/mminfo  -r volume -q '!full,written<$THRESHHOLD,location=$jukebox,pool=$QPOOL' | /bin/sort | /bin/uniq 2>&1| /usr/bin/wc -l`;
        if ($number_of_tapes_available =~ /no matches found for the query/) { $number_of_tapes_available=0};
        chop $number_of_tapes_available;
        print "\nNumber of tapes available for writing in Jukebox $jukebox using less than $THRESHHOLD = $number_of_tapes_available\n";
        print "Current value for minimum Number of days of retention required = $number_of_days\n";
        print "Number of tapes needed for today's backup = $NUMBER_OF_TAPES_NEEDED\n";
        $number_of_tapes_required = $NUMBER_OF_TAPES_NEEDED - $number_of_tapes_available;
        if ($number_of_tapes_required < 0) {$number_of_tapes_required=0};
        print "To meet today's requirement we need to free up $number_of_tapes_required additional tapes\n\n";

        print "\nHow many tapes do you want to add to this count\n";
        $howmuch = <STDIN>;
        if ($howmuch =~ /^\s+$/) { 
           $howmuch=0.0;
        } else {
             chop $howmuch;
        }

        if ($howmuch < 0.0) {$howmuch=0.0};
        if ($howmuch > $max_tapes_at_a_time) {
           print "Can't add more than $max_tapes_at_a_time additional tapes\n";
           $howmuch=$max_tapes_at_a_time;
        }
        $number_of_tapes_required = $number_of_tapes_required+$howmuch;
        if ($number_of_tapes_required <= 0) {
           print "Since we already have $number_of_tapes_available tapes available, no additional tapes required.\n";
           next;
        }
        IYORN:
        print "Do you want to just get a list of the tapes to recycle (y or n)\n";
        $iyorn = <STDIN>;
        if ($iyorn !~ /y/ && $iyorn !~ /n/) {goto IYORN};
        # Get a list of all the tapes and sort them oldest to newest
        #print "/usr/sbin/mminfo -o em -av -r volume,volretent -q location=$jukebox,pool=$SPOOL,savetime>last decade\n";
        
        # Get a list of the tapes that are recyclable in the jukebox(yes) or no longer in the media database(*)
        undef @recyclable;
        undef @recycle;
        (@recyclable) = `/usr/sbin/nsrjb -j $jukebox -C | /bin/egrep -e "^[ ]*[0-9]+:[ ]+[A-Z0-9]+\\\* |yes"`;
        # 457: SSCS0457       SSCSD     SSCS0457  3362057591      yes
        if (defined @recyclable) {
           foreach $check (@recyclable) {
              ($check) = ($check =~ /^.+:\s+(\S+)\*?.+/);
              if ($check =~ /\S+/) {
                ($check) = ($check =~ /\~*(\w+)\**/); 
                $check="$check     01/01/00\n";
                push (@recycle,$check);
             }
           }
        }
        #print "Above first mminfo\n";
        #print "/usr/sbin/mminfo -o em -av -r volume,volretent -q location=$jukebox,pool=$SPOOL,savetime>last decade\n";
        (@volretent) = `/usr/sbin/mminfo -o em -av -r "volume,volretent" -q "location=$jukebox,pool=$SPOOL,savetime>last decade,savetime<$number_of_days days ago" | /bin/sort | /bin/uniq  2>&1`;
        if ($volretent[0] =~ "no matches found for the query") {
           print "No savesets found on volumes for jukebox $jukebox\n";
           next;
        }
        if (defined @recycle) {unshift(@volretent,@recycle)};
        foreach $_ (@volretent) {
           next if $_ =~ /volume/;
           chop $_;
           ($volume,$volaccess) = split(/\s\s+/,$_);
           print "Volume to check $volume,$volaccess\n";
           if ($_ =~ "[Vv]olume") {
              next;
           } elsif ($_ =~ "expired") {
              print "Expired Volume =$volume,\n";
              $year=  0;
              $day =  1;
              $mon =  1;
           } elsif ($_ =~ "undef") {
              print " Volume with undef volaccess =$volume\n";
              $year=  1;
              $day =  1;
              $mon =  1;
           } else {
              next if $volaccess =~ /0 KB/;
              #print "Volume=$volume, Date=$volaccess\n";
              ($mon,$day,$year) = split(/\//,$volaccess);
              # Check for ADIC changeover to year retention
	      #if ($jukebox =~ /ADIC/) {
              #   next if $year > 110;
              #   next if $mon > 4;
              #   next if $mon==4 && $day>19;
              #}
           }
        
           $year = $year+1900;
           #$mon  = $mon -1;
           next if ($day <1 || $day > 31);
           $year=sprintf("%04d",$year);
           $mon=sprintf("%02d",$mon);
           $day=sprintf("%02d",$day);
           $key="$year$mon$day$volume";
           print "Volume after key=$volume,key=$key\n";
           $bytime{$key} = $volume; 
        }
        $number_of_tapes=1;
        $now = time ;    #- 24*3600*20;
        $retention = $now - $delta;
        my $vvv;
        #foreach $key (sort numerically (keys %bytime)) {
        if (!defined %bytime) {print "There are no elements in bytime\n"};
        if (defined %bytime) {
         # Sort in reverse order all tapes in jukebox
         #$volchk="SSCN1229";
         $volchk="abcd";
   

         #Loop through the tapes
         #print "Above tape loop\n";
         foreach $key (sort (keys %bytime)) {
           print "Key=$key\n";
           #next unless ($bytime{$key} eq 'SSCN1203');

           # Want to keep track of how many ssids are not backed up
           $notcopied=0;
           $not_expired=0;

           #if the tape is expired don't do any checks
           print "Key=$key, volume=$bytime{$key}\n";
           if ($key =~ /1000001/ ) {goto DELETETAPE};

           if ($bytime{$key} eq $volchk) {print "Inside Volume loop $bytime{$key}\n"};
           # check to see if the incremental saves are backed up to physical tape.  The fulls won't be
           # Don't do incremental check if the tapes are physical
             
           if ($jukebox !~ /ADIC/) {
              print "Volume Name=$bytime{$key}\n";
              (@incrementals) = `/usr/sbin/mminfo -xc, -av -r "ssid(53),fragflags" -q "volume=$bytime{$key},level=incr" 2>&1 | /bin/sort | /bin/uniq`;
              next if !defined @incrementals; 

              # There are no incremental backups on the tape
              if ($incrementals[0] =~ /no matches found for the query/) { goto DELETETAPE};
              undef %ssid_sort;
              foreach $sorter (@incrementals) { 
                chop $sorter;
                ($incr,$fragflags) = split(/,/,$sorter);
                if ($fragflags =~ /a/) {next};
                $ssid_sort{$incr} += 1;
              }


              # Look at each ssid on the tape and check to see if there is a backup in pool SSCNCLN 
              foreach $incr (sort (keys %ssid_sort)) {
                 if ($bytime{$key} eq $volchk) {print "SSID=$incr\n"};
                 if ( $incr =~  /no matches found for the query/ ) {
                    $notcopied=0;
                    # No incrementals on tape so all incrementals are backed up
                    if ($bytime{$key} eq $volchk) {print "No incremental savesets on volume $volume\n"};
                    goto DELETETAPE;
                 } elsif ($incr =~ /[Ss]sid/) {
                    # Skip the header
                    if ($bytime{$key} eq $volchk) {print "Skip header on volume\n"};
                    next;
                 } else {
                    # There are incrementals on tape
                    (@pool) = `/usr/sbin/mminfo -xc, -av -r "pool,nsavetime,clflags" -q "ssid=$incr,pool=$DPOOL" 2>&1`;
                    $copy = 0;
                    foreach $po (@pool) {
                      chop $po;
                      if ($bytime{$key} eq $volchk) {print "Po=$incr,$po\n"};
                      if ($po =~ "no matches found for the query") {
                          # This means that the ssid is not backed up to physical
                          # Returned on backups to SSCNCLN
                          print "SSID $incr not backed up to physical tape\n";
                          $notcopied+=1;
                          goto NEXTSSID;
                      }elsif ($po =~ /[Pp]ool/) {
                          if ($bytime{$key} eq $volchk) {print "Skip the header in pool check $po"};
                          # Skip the header
                          next;
                      } else {

                          ($pool,$nsavetime,$clflags) = split(/,/,$po);
                          if ($clflags !~ /E/) { 
     
                             if ($nsavetime > $retention) {
                                if ($bytime{$key} eq $volchk) {
                                    print "Tape $bytime{$key},$incr has expired\n";
                                }
                                $not_expired+=1;
                             }
                          }
 
                          if ($po =~ /$DPOOL/ ) {
                             #print "PO=$po before SSCNCLN\n";
                             $copy+=1; 
                             $nsavetime=0;
                             if ($bytime{$key} eq $volchk) {
                                print "Volume=$bytime{$key},PO=$po,Pool=$pool, Savetime=$nsavetime,  Retention=$retention\n";
                             }
                          }
                      }
                    }
                    if ($copy == 0) {
                      #print "Inside copy loop SSID $incr not copied\n";
                      $notcopied+=1;
                      if ($bytime{$key} eq $volchk) {print "Copy=$copy, Notcopied=$notcopied\n"};
                    }
                 }
                 NEXTSSID:
              }
           } else {
             # Physical tape drive
             # Are all the ssid's past retention time
             print "In physical tape drive volume=$bytime{$key}, key=$key\n";
             (@incrementals) = `/usr/sbin/mminfo -xc, -av -r "nsavetime,clflags" -q "volume=$bytime{$key}" | /bin/sort | /bin/uniq 2>&1`;
             if (!defined @incrementals) {goto DELETETAPE}; 
             if ($incrementals[0] =~ "no matches found for the query") {goto DELETETAPE};

             foreach $exp_check (@incrementals) {
                next if $exp_check =~ /savetime/;
                ($nsavetime,$clflags) = split(/,/,$exp_check);

                if ($clflags !~ /E/) { 
                   if ($nsavetime > $retention) {
                      if ($bytime{$key} eq $volchk) {print "Tape $bytime{$key},$incr has expired\n"};
                      $not_expired+=1;
                   }
                }
             }

           }

           #print "Notcopied out=$notcopied\n";
           DELETETAPE:
           #print "Deletetape volume=$bytime{$key}\n";
           $checkskip = $notcopied + $not_expired;
           if ($checkskip > 0) {
              print "\nSkipping tape $bytime{$key} because checks are not zero. Not copied=$notcopied Not Expired=$not_expired\n\n"; 
              # Check to see if we now exceeded our retention times
              $failures+=1;
              if ($failures>20) {last};
              next;
           }
           if ($iyorn eq 'y') { 
              print "$bytime{$key}\n";
           } else {
             if ($bytime{$key} !~ /\s+/) { 
              $slot =  &which_slot($bytime{$key},$jukebox);
              # This writes a file
              $!=0;
              #print SAVETAPES "\n/usr/sbin/nsrmm -d -y -v $bytime{$key}\t    # No Copies $notcopied   # Not Expired $not_expired\n";
              #print SAVETAPES "/usr/sbin/nsrjb -L -j $jukebox -S $slot -Y -b $DPOOL $bytime{$key}\n";

              # This performs the operation
              print "\n/usr/sbin/nsrjb -u $bytime{$key}\t    # No Copies $notcopied   # Not Expired $not_expired\n";
              my $return=999;
              $return = `/usr/sbin/nsrjb -u $bytime{$key}`;
              print "Return from unmounting tape $volume, $return";
              if ($! !~ /Illegal seek/) {
                 print ", $!\n";
              } else {
                 print "\n";
              }
              # Delete the tape
              print "/usr/sbin/nsrmm -d -y -v $bytime{$key}\n";
              $return = `/usr/sbin/nsrmm -d -y -v $bytime{$key}`;
              print "Return from deleting tape $volume, $return";
              if ($! !~ /Illegal seek/) {
                 print ", $!\n";
              } else {
                 print "\n";
              }
              # Label the tape
              print "/usr/sbin/nsrjb  -L -c $capacity -J $backup_server -S $slot -Y -j $jukebox -b $DPOOL $bytime{$key}\n";
              $return=`/usr/sbin/nsrjb  -L -c $capacity -J $backup_server -S $slot -Y -j $jukebox -b $DPOOL $bytime{$key}`;
              print "Return from labeling tape $volume, $return";
              if ($! !~ /Illegal seek/) {
                 print ", $!\n";
              } else {
                 print "\n";
              }
             }
           } 
           #print "Tape = $bytime{$key}, $key\n";
           ++$number_of_tapes;
           if ($number_of_tapes>$number_of_tapes_required) {last};
           # Just to make sure
           if ($number_of_tapes>150) {last};
         }
        }      # End of defined bytime check
}


sub which_slot {
   ($volume,$jukebox) = @_;
   open (SLOT,"/usr/sbin/nsrjb  -C -j $jukebox $volume|");
   my ($rest,$return);
   while (<SLOT>) {
     if ($_ =~ /^\n/) {next};
     if ($_ =~ /Jukebox/) {next};
     if ($_ =~ /slot/) {next};
     if ($_ =~ /$volume/ ) {
        ($slot,$rest)=split(/:/,$_);
        goto RET;
     } else {
        print "\n\n\n*********************Jukebox has problems, ending program \n";
        exit;
     }
   }
RET:
   close SLOT;
   $return = $slot;
}

