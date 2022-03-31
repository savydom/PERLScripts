#!/usr/bin/perl -w
# Argument 1   -> Mail Addresses
# Argument 2   -> Report Period (0-4)
# Argument 3   -> Detailed (1) or not detailed(0)
$weekend_total = 0;
$number_of_files_total = 0;
%pool_type = (
'BackupM',		'backup',
'Auditlog',		'backup',
'NavyNuclear',		'backup',
'ServerRecover',	'backup',
'ServerRecoverClone',	'clone',
'SSCNCLN', 		'clone',
'SSCNOLA',		'backup',
'SscsdDIC',		'backup',
'SscnolaADIC',		'backup',
'SSCNOLALTO5',		'backup',
'SSCSD',		'backup',
'NATO',			'backup',
'AFTD_POOL',		'backup',
'ldom',			'backup',
'VADP',			'backup',
'SscsdADIC',		'backup',
'AuditClone',		'clone',
'SSCSCLN',		'clone'
);

(@servers) = ('sscprodeng', 'sdprodeng');
#(@servers) = ('sscprodeng');
#(@servers) = ('sdprodeng');
(@periods) = ("\'savetime>yesterday 17:00\'",
              "\'savetime>last friday 18:00,savetime<today 16:00\'",
              "\'savetime>last saturday 17:00,savetime<monday 7:00\'",
              "\'savetime>last saturday 17:00,savetime<last sunday 22:00\'",
              "\'savetime>last sunday 22:00,savetime<today 21:00\'"
);

if ($ARGV[1] == '0') {
   $report_period=0;
} elsif ($ARGV[1] == '1') {
   $report_period=1;
} elsif ($ARGV[1] == '2') {
   $report_period=2;
} elsif ($ARGV[1] == '3') {
   $report_period=3;
} elsif ($ARGV[1] == '4') {
   $report_period=4;
} else {
   $report_period=0;
}
if (undef $ARGV[3]) {
   $remedy = 0;
} else {
   $remedy = 1;
}

%convert_month = (Jan,0,Feb,1,Mar,2,Apr,3,May,4,Jun,5,Jul,6,Aug,7,Sep,8,Oct,9,Nov,10,Dec,11);


########################## User configuration ##########################################

#--> Set up mail addresses for the people to be notified
#$FAILADDRS="peter.reed.ctr\@navy.mil bobby.billiot.ctr\@navy.mil  jeffrey.l.rodriguez.ctr\@navy.mil cody.p.crawford.ctr\@navy.mil";
$FAILADDRS="peter.reed.ctr\@navy.mil bobby.billiot.ctr\@navy.mil jeffrey.l.rodriguez.ctr\@navy.mil cody.p.crawford.ctr\@navy.mil chris.bowman\@navy.mil brian.brouillette.ctr\@navy.mil michael.yoli.ctr\@navy.mil eugene.brandt.ctr\@navy.mil brandon.generes\@navy.mil melissa.earhart\@navy.mil jared.m.anderson\@navy.mil"; 
#$FAILADDRS=
#"peter.reed.ctr\@navy.mil \
#bobby.billiot.ctr\@navy.mil \
#jeffrey.l.rodriguez.ctr\@navy.mil \
#cody.p.crawford.ctr\@navy.mil \
#chris.bowman\@navy.mil \
#brian.brouillette.ctr\@navy.mil \
#michael.yoli.ctr\@navy.mil \
#eugene.brandt.ctr\@navy.mil \
#brandon.generes\@navy.mil"; 
#edward.brightman.ctr\@navy.mil \
#brian.k.cobb.ctr\@navy.mil \
#mary.decoteau.ctr\@navy.mil \
#wilbert.dwyer.ctr\@navy.mil \
#robert.c.evans3.ctr\@navy.mil \
#robert.galloway.ctr\@navy.mil \
#mark.d.johnson5.ctr\@navy.mil \
#james.k.langston.ctr\@navy.mil \
#christopher.j.ledet.ctr\@navy.mil \
#gregory.d.mull.ctr\@navy.mil \
#jonathan.v.nguyen.ctr\@navy.mil \
#adam.zehner.ctr\@navy.mil \
#lenny.zimmermann.ctr\@navy.mil \
#anthony.uchello.ctr\@navy.mil \
#rickey.j.carter.ctr\@navy.mil \
#ronald.l.porter.ctr\@navy.mil \
#alberto.cardenas1.ctr\@navy.mil \
#derek.bouysou.ctr\@navy.mil \
#john.m.ivy.ctr\@navy.mil \
#arthur.groteguth.ctr\@navy.mil \
#andre.poole.ctr\@navy.mil";
#$FAILADDRS="peter.reed.ctr\@navy.mil";
#    Addressses are separated by spaces
#    Can't have any spaces on either side of = sign
#    Example: MAILADDRS="peter.reed@navy.mil kenneth.g.magee.ctr@navy.mil katherine.hosch@navy.mil"
if ($ARGV[0] == '1') {
   $MAILADDRS="peter.reed.ctr\@navy.mil bobby.billiot.ctr\@navy.mil nedc_doc-new_orleans\@navy.mil jeffrey.l.rodriguez.ctr\@navy.mil";
#      $MAILADDRS="peter.reed\@navy.mil christopher.m.scully\@navy.mil joseph.wronkowski.ctr\@navy.mil bobby.billiot.ctr\@navy.mil lenny.zimmermann\@navy.mil charles.buzbee.ctr\@navy.mil april.sanangelo.ctr\@navy.mil nicholas.dobson.ctr\@navy.mil charles.dileo.ctr\@navy.mil michael.yoli\@navy.mil beverly.dupree\@navy.mil steven.hollars\@navy.mil paul.plummer\@navy.mil daniel.whitecotton\@navy.mil robert.c.evans3.ctr\@navy.mil chad.mays.ctr\@navy.mil james.schaefer\@navy.mil earnest.mouton\@navy.mil kathy.daniels\@navy.mil brian.price1\@navy.mil laura.gilbreath\@navy.mil al.cassedy.ctr\@navy.mil artis.silvester\@navy.mil chad.appe\@navy.mil john.luedke\@navy.mil";

} elsif ($ARGV[0] == '2') {
   $MAILADDRS="peter.reed.ctr\@navy.mil";

} elsif ($ARGV[0] == '3') {
   $MAILADDRS="peter.reed.ctr\@navy.mil";

} elsif ($ARGV[0] == '4') {
   $MAILADDRS="peter.reed.ctr\@navy.mil";

} else {
   print "Bad input argument for mail addresses\n";
   exit;
}

if ($ARGV[2] == '1') {
   $detailed = '1';
} else {
   $detailed = '0';
}

# Determine real world units

# week_day -> $wday begins with Sunday (0) till Saturday (6)
use Time::Local;

# Get the current time
$seconds_from_1970 = time;
($sec,$min,$hr,$mday,$mon,$yr,$wday) = (localtime($seconds_from_1970))[0,1,2,3,4,5,6];
++$mon;
$yr = $yr+1900;
$thisday= (Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$wday];

# Create the output file
$mon = sprintf("%02d",$mon);
$mday= sprintf("%02d",$mday);
$sec = sprintf("%02d",$sec);
$min = sprintf("%02d",$min);
$hr  = sprintf("%02d",$hr);
$date="$yr$mon$mday-$hr$min$sec\.$thisday";
$petedate="pete$date";
$prtdate="$mon/$mday/$yr $hr:$min:$sec";
$STAMP="$thisday $mon/$mday/$yr $hr:$min";
open(TMPFILE,">/nsr/local/MorningReports/$date") or die "Can't open file /nsr/local/MorningReports/$date";
open(FAILFILE,">/nsr/local/MorningReports/FailedLIST") or die "Can't open file /nsr/local/MorningReports/FailedLIST";
print TMPFILE "mailx -s 'Backup report for $STAMP' $MAILADDRS <<ENDMAIL\n";
open(FAILMAIL,">/nsr/local/MorningReports/Fail$date") or die "Can't open file /nsr/local/MorningReports/Fail$date";
print FAILMAIL "mailx -s 'Backup Failures for $STAMP' $FAILADDRS <<ENDMAIL\n";
open(TMPPETE,">/nsr/local/MorningReports/$petedate") or die "Can't open file /nsr/local/MorningReports/$petedate";
print TMPPETE "mailx -s 'Backup report for $STAMP' pt01892\@gmail.com reep_p\@yahoo.com <<ENDMAIL\n";

$user = 'preed';

# New Orleans
$site = 'New Orleans';
$physical = '   ADIC';

$yesterday = $seconds_from_1970-24*3600;
($mday,$mon,$yr,$wday) = (localtime($yesterday))[3,4,5,6];
$yr = $yr+1900;
$mon +=1;
$mon = sprintf("%02d",$mon);
$mday= sprintf("%02d",$mday);
$thisday= (Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$wday];
if ($ARGV[1] >  1) {
	$STAMP = $periods[$report_period];
} else {
	$STAMP="$thisday $mon/$mday/$yr > 17:00";
}
foreach $server (@servers) {
   if ($server eq 'sdprodeng') {$site='San Diego';$physical='SD-LTO3'};

   print TMPFILE "\n\n************************************************************************\n";
   print TMPFILE     "                Backup Server $server in $site\n";
   print TMPFILE     "                      Night of $STAMP\n";
   print TMPFILE     "                    Report Time $prtdate\n";
   print TMPFILE     "************************************************************************\n";
   print TMPPETE "\n\n************************************************************************\n";
   print TMPPETE     "                Backup Server $server in $site\n";
   print TMPPETE     "                      Night of $STAMP\n";
   print TMPPETE     "                    Report Time $prtdate\n";
   print TMPPETE     "************************************************************************\n";
   $server_total=0;
   $server_total_files=0;
   $server_total_suspect=0;
   $server_total_filesystems=0;
   undef @failed;
   undef @failed_servers;
   undef %failed_test;
   undef %ffailed;
   undef %file_systems;
   undef %files_used;
   undef %jukeboxes;
   undef %locations;
   undef %number_of_file_systems;
   undef %size_used;
   undef @succeeded;
   undef %succeeded_test;
   undef %suspect;
   undef %suspected;
   undef %track_clients;
   undef %track_groups; 

   #-> Get the info about the recent backups
   #print "/usr/sbin/mminfo -s $server -xc, -r 'group,volume,pool,location,totalsize,nfiles,clflags' -q pssid=0 -q $periods[$report_period]\n";
   (@mminfo) =  `/usr/sbin/mminfo -s $server -xc, -r 'group,volume,pool,location,totalsize,nfiles,fragflags,client,name,clflags,ssflags' -q pssid=0 -q $periods[$report_period] 2>&1`;

   if ($mminfo[0] =~ "no matches found for the query") {
          print "Didn't find any data backed up $periods[$report_period]\n";
          print TMPPETE "Didn't find any data backed up $periods[$report_period]\n";
          exit;
   }


   #->  Calculate all mminfo values

   foreach $val (@mminfo) {
     # Take off end of line
     chop $val;
     #print "$val\n";
     
     # Get rid of header 
     if ($val =~ 'group') {next};
     # Break into columns

     ($GROUP,$VOLUME,$POOL,$LOCATION,$TOTALSIZE,$NFILES,$FRAGFLAGS,$CLIENT,$NAME,$CLFLAGS,$SSFLAGS) = split(/,/,$val);
     if ($LOCATION =~ 'i2000' | $LOCATION =~ 'ADIC' | $LOCATION =~ 'LTO3' | $POOL =~ 'AFTD' ) {
        # Non Blank location
     } else {
        #print "Undefined Location $VOLUME,$LOCATION,$POOL\n";
        next;
     }

     #if ($units =~ 'KB') {
     #   $val1=$TOTALSIZE*1024;
     #} elsif ($units =~ 'MB') {
     #   $val1=$TOTALSIZE*1024*1000;
     #} elsif ($units =~ 'GB') {
     #   $val1=$TOTALSIZE*1024*1000*1000;
     #} elsif ($units =~ 'TB') {
     #   $val1=$TOTALSIZE*1024*1000*1000*1000;
     #} elsif ($units =~ 'B') {
     #   $val1=$TOTALSIZE;
     #} else {
     #   print "Error units=$units\n";
     #   $val1=0;
     #}
     if ($FRAGFLAGS =~ /^[hc]/) {
         $val1=$TOTALSIZE;
         $merge="$CLIENT\[$NAME\[$VOLUME";
         if ($CLFLAGS =~ /s/) { 
            # Check for skips 
            if ($TOTALSIZE != 4) {
              # print "Totalsize=$TOTALSIZE,  Merge=$merge\n";
              # Check for in progress
              #if ($SSFLAGS !~ /I/) {
              #if ($SSFLAGS !~ /F/) {
              if ($SSFLAGS !~ /[iI]/) {
                 #print "SSFLAGS=$SSFLAGS\n";
                 $suspect{$GROUP} +=1;
                 $suspected{$merge} +=1;
                 #print "$GROUP,$VOLUME,$POOL,$LOCATION,$TOTALSIZE,$NFILES,$FRAGFLAGS,$CLIENT,$NAME,$CLFLAGS,$merge\n";
              }
            }
         }
         if ($val1 != 4) {$number_of_file_systems{$GROUP} += 1};
         #print "name=$NAME, client=$CLIENT\n";
         $NAME =~ s/\\/\//g;
         $file_systems{$merge} += 1;
     } else {
         $val1=0;
         $NFILES=0;
     }

#   Need to handle problems caused by totals being messed up by cloning
     if (defined $pool_type{$POOL} ) {
        if ($pool_type{$POOL} =~ /backup/) {
            next if $val1==4;
            #print "---------Group=$GROUP\n";
            $size_used{$GROUP} += $val1;
            $files_used{$GROUP} += $NFILES;
        }
     } else {
        print "***********************Pool type not defined for $POOL\n"; 
     }
     # Determine the tapes per jukebox
     $locations{$VOLUME} = $LOCATION;
     if (defined $LOCATION ) {
        if ($LOCATION ne '') {
           $jukeboxes{$LOCATION} = 0;
        }
     }
     $tape_pool{$VOLUME} = $POOL;
     #print "Tape Pool $tape_pool{$VOLUME}\n";
     # Determine the number of clients per group
     $groupclient = "$GROUP:$CLIENT";
     if ($CLIENT !~ /sscprodeng/) {$track_groups{$groupclient} = 1};
     $track_clients{$CLIENT} = 1;
   } 
   $computed_number_of_clients = 0;
   my $abscd;
   foreach $abscd (keys %track_clients) {
     $computed_number_of_clients+=1;
   }
   #->  Determine number of tapes used in each jukebox 
   #->  Determine number of tapes used in each jukebox 
   $number_of_tapes_used = 0;
   #print "Above location calculation";
   foreach $location (values %locations) {
      $jukeboxes{$location} += 1;
      $number_of_tapes_used += 1;
      #print "Location=$location,Tapes in juke=$jukeboxes{$location} \n";
   }
   #foreach $VVVV (sort keys %locations) {
   #  print "$VVVV\n";
   #}
           
   #-> Create list of groups used
   (@groups) = (sort keys %files_used);


   #foreach $key (sort(keys %jukeboxes)) {
   #  print "Volume=$key,Location=$jukeboxes{$key}\n";
   #}
   print  TMPFILE "                                     Total Size     Number    Total Time\n";
   print  TMPFILE "G R O U P   N A M E                     (GB)       of Files/     (min)/\n";
   print  TMPFILE "                                                 Susp/FileSys   MB/Sec\n";
   print  TMPFILE "--------------------------------     ----------  ------------ ----------\n";
   print  TMPPETE "                                     Total Size     Number    Total Time\n";
   print  TMPPETE "G R O U P   N A M E                     (GB)       of Files/     (min)/\n";
   print  TMPPETE "                                                 Susp/FileSys   MB/Sec\n";
   print  TMPPETE "--------------------------------     ----------  ------------ ----------\n";
   # Want to keep track of number of zero or one client backups for bkproxy (P1) or bkproxy2 in name
   $BKPROXY1_FAILS = 0;
   $BKPROXY2_FAILS = 0;



   foreach $group (@groups) {
     next if $group =~ /Auditlog/;
     next if $group =~ /^\s*$/;
     next if $group =~ /INDEX/;
     next if $group =~ /AFTD Test/;
     #print "Group name =$group---\n";
     # Compute time required for group
     $nsrpass = ". type:NSR group\\;name:$group'\n'show name\\;last start\\;last end\\;action'\n'print"; 
     @values =  `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $server -i -`;
     foreach $value (@values)  {
       # Fill in name when find last start
       if ($value =~ /last start:/) {
         #print "Last start=$value\n";
         if ($value =~ /last start: \;/) {
            $value='Not Started'; 
            print "At top start_secs=$start_secs\n";
            $start_secs=$seconds_from_1970;
            next;
         } else {
            $printstart = $value;
            #($start) = ($value =~ m/^\s+last start:\s\"(.+)\"\;/);
            # Tue Oct 21 23:30:00 2008
            #last start: "Mon Mar 30 23:50:00 2009";
            ($wday,$mon,$mday,$hr,$min,$sec,$yr) = $value =~ /^\s+last start:\s+\"(\w+)\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d+)\"/;
            $md = sprintf("%02d",($mday));
            $month = $convert_month{$mon};
            $year = $yr-1900;
            $md = sprintf("%02d",($mday));
            $start_secs = timelocal($sec,$min,$hr,$mday,$month,$year);
            $h = sprintf("%02d",($hr));
            $m = sprintf("%02d",($min));
            $s = sprintf("%02d",($sec));
            $savegroup_name = "/nsr/Summaries/$yr$mon$md\_$h$m$s\_$wday\_$group";
         }
       } elsif ($value =~ /last end:/) {
         if ($value =~ /last end: \;/) {
            $delta = 'Not finished';
            $end_secs=$seconds_from_1970;
            next;
         }
         $printend = $value;
         ($end) = ($value =~ m/^\s+last end:\s\"(.+)\"\;/);
          my ($day,$mon,$mday,$hr,$min,$sec,$year);
         ($day,$mon,$mday,$hr,$min,$sec,$year)= ($end =~ m/(^\S+)\s(\S+)\s(..)\s(\d\d)\:(\d\d)\:(\d\d)\s(\d\d\d\d)/);
         $month = $convert_month{$mon};
         $yr = sprintf("%02d",($year-2000));
         $md = sprintf("%02d",($mday));
         $h = sprintf("%02d",($hr));
         $m = sprintf("%02d",($min));
         $s = sprintf("%02d",($sec));
         #$mo = sprintf("%02d",($month+1));
         # Succeeded with warning(s):
	 # Failed: 
	 # Succeeded:
	 # Succeeded after CPR: Check point enabled
         # (@failed)    = `/usr/bin/ssh -q $user\@$server "/usr/xpg4/bin/grep '^Failed:' $savegroup_name" 2>/dev/null`;
         # (@succeeded) = `/usr/bin/ssh -q $user\@$server "/usr/xpg4/bin/grep '^Succeeded' $savegroup_name" 2>/dev/null`;
 	 #2017Jan04_233802_Wed_VADP-Prodint-Ch2-610-B9
         #print "/usr/bin/ssh -q $user\@$server /usr/xpg4/bin/grep \'^Failed\' \'$savegroup_name\'\n";
         #print "/usr/bin/ssh -q $user\@$server /usr/bin/ls -1 '$savegroup_name'\n";
         $return = `/usr/bin/ssh -q $user\@$server /usr/bin/ls -1 '$savegroup_name' 2>&1`;
         if ($return !~ /No such file or directory/) {
            (@failed)    = `/usr/bin/ssh -q $user\@$server "/usr/xpg4/bin/grep \'^Failed\'  \'$savegroup_name\' 2>/dev/null"`;
            #print "/usr/bin/ssh -q $user\@$server /usr/xpg4/bin/grep \'^Succeeded\'  \'$savegroup_name\'\n";
            (@succeeded) = `/usr/bin/ssh -q $user\@$server "/usr/xpg4/bin/grep \'^Succeeded\' \'$savegroup_name\' 2>/dev/null"`;
            #print "Right after @succeeded\n";
	 } else {
            # Kludge for time roundoff
            # Could this be done just by checking for file existence
            # Check for roundoff add a second
            #if (!defined $failed[0]) {
            $ss = sprintf("%02d",($s+1));
            $savegroup_name = "/nsr/Summaries/$yr$mon$md\_$h$m$ss\_$wday\_$group";
            if (-e $savegroup_name) {
               #print "Kludge_Savegroup Name=$savegroup_name\n";
               (@failed2) = `/usr/bin/ssh -q $user\@$server "/usr/xpg4/bin/grep \'^Failed\' \'$savegroup_name\'" 2>/dev/null`;
               (@succeeded2) = `/usr/bin/ssh -q $user\@$server "/usr/xpg4/bin/grep \'^Succeeded\' \'$savegroup_name\'" 2>/dev/null`;
               push(@failed,@failed2);
               push(@succeeded,@succeeded2)
            }
         }
         foreach $fff (@failed) {
             chomp $fff;
             $temp = $fff;
             #next if $fff =~/grep: can't open/;      # Should be handled by passing return to /dev/null
             $temp =~ s/^Failed.*\: //;
             (@temp_failed) = split(/,\s*/,$temp);
             #print "Number of failed servers = $#temp_failed for group $group\n";
             foreach $ggg (@temp_failed) {
                $ggg = lc $ggg;
                if (defined $failed_test{$ggg}) {
                   #print "Server Failed=$ggg, Start Seconds=$start_secs, Current Value=$failed_test{$ggg}, $group----\n"; 
                   # The value has already been set so check to see if it should be updated
                   if ($start_secs > $failed_test{$ggg}) {$failed_test{$ggg} = $start_secs};
                } else {
                   $failed_test{$ggg} = $start_secs;
                   $failed_test_group{$ggg} = $group;
                }
             }
         }
         # Have to keep track of all succeeded and failed to test at the end, succeeded group could process before failed group
         # Could also sort by group start times which might be better.
         # If the succeeded came after the failed then it could be removed
         foreach $fff (@succeeded) {
             chomp $fff;
             #next if $fff =~/grep: can't open/; 
             $temp = $fff;
             $temp =~ s/^Succeeded.*\: //;
             (@temp_succeeded) = split(/,\s*/,$temp);
             foreach $ggg (@temp_succeeded) {
                $ggg = lc $ggg;
                if (defined $succeeded_test{$ggg}) {
                   #print "Server Succeeded=$ggg, Start Seconds=$start_secs, Current Value=$succeeded_test{$ggg}, $group-----\n"; 
                   # The value has already been set so check to see if it should be updated
                   if ($start_secs > $succeeded_test{$ggg}) {$succeeded_test{$ggg} = $start_secs};
                } else {
                   $succeeded_test{$ggg} = $start_secs;
                }
             }
         }
         $year = $year-1900;
         $end_secs = timelocal($sec,$min,$hr,$mday,$month,$year);
         $delta_seconds=$end_secs-$start_secs;
         $delta = $delta_seconds/60;
         $delta = sprintf "%10.2f",$delta;
       }
     }

#     # Do test to generate failed_servers array
#     # Really only concerned with the failures for loop on failed servers
#     foreach $fff (sort keys %failed_test) { 
#        if (  (defined $succeeded_test{$fff}))  {print "Succeeded $succeeded_test{$fff}, Failed $failed_test{$fff}"};
#        if (  (defined $succeeded_test{$fff} )  && ($succeeded_test{$fff} > $failed_test{$fff}) ) {next};
#        $ffailed{$fff} =$failed_test_group{$fff};
#     }

     $totalsize=$size_used{$group}/1024/1000/1000;
     $server_total += $totalsize;

     $numberfiles=$files_used{$group};
     $server_total_files += $numberfiles;
     #$numberfiles = sprintf "%9.0f",$numberfiles;
     # Determine number of clients per group
     $number_of_clients_per_group = 0;
     foreach $ggg (sort keys(%track_groups)) {
       if ($ggg =~ /$group:/) {$number_of_clients_per_group+=1};
     }
     #$number_of_clients_per_group=sprintf "%3.0f",$number_of_clients_per_group; 
     if ($group =~ /VADP/) {
        if ($number_of_clients_per_group < 2) {
           if ($group =~ /P1/) {$BKPROXY1_FAILS += 1};
           if ($group =~ /P2/) {$BKPROXY2_FAILS += 1};
        }
     }
     $ggroup = "$group ($number_of_clients_per_group)";
     $val        =sprintf"%-32s",$ggroup;
     #$totalsize  =sprintf "%11.2f",$totalsize; 
     $rate_per_second=0;
     if ( defined $delta_seconds && ($delta_seconds != 0) ) {$rate_per_second=$totalsize*1024/$delta_seconds};
     $rate_per_second = sprintf "%10.2f",$rate_per_second;
     $totalsize = format_number($totalsize,'2','r',10);
     #$numberfiles= commify($numberfiles);
     #$numberfiles=sprintf "%12.0f",$numberfiles; 
     $number_of_files_total += $numberfiles;
     $numberfiles = format_number($numberfiles,0,'r',12);
     if (!defined $number_of_file_systems{$group}) {$number_of_file_systems{$group}=0};
     if (!defined $suspect{$group}) {$suspect{$group}=0};
     $server_total_filesystems +=$number_of_file_systems{$group};
     $server_total_suspect +=$suspect{$group};
     #$suspect{$group} = format_number($suspect{$group},'0','c',12);
     $val12 = "$suspect{$group}\\$number_of_file_systems{$group}";
     $val12 = sprintf"%12s",$val12;
     #-> Print Group Totals
     ######################### Pete Updates ##############################
     print TMPFILE "\n$val     $totalsize  $numberfiles $delta\n";
     print TMPPETE "\n$val     $totalsize  $numberfiles $delta\n";
     $printstart =~ s/\s+last start: \"/\(S\)/;
     $printstart =~ s/\"\;//;
     chop $printstart;
     if (defined $printend) {
        $printend =~ s/\s+last end: \"/\(E\)/;
        $printend =~ s/\"\;//;
        chop $printend;
     } else {
        $printend='';
     }
     print TMPFILE "     $printstart                 $val12 $rate_per_second\n"; 
     print TMPFILE "     $printend\n"; 
     print TMPPETE "     $printstart                 $val12 $rate_per_second\n"; 
     print TMPPETE "     $printend\n"; 
   }



   ######## End of group loop
   # Do test to generate failed_servers array
   # Really only concerned with the failures for loop on failed servers
   foreach $fff (sort keys %failed_test) { 
      if (  (defined $succeeded_test{$fff} )  && ($succeeded_test{$fff} > $failed_test{$fff}) ) {next};
      $ffailed{$fff} =$failed_test_group{$fff};
   }

   # Do test to generate failed_servers array
   # Really only concerned with the failures for loop on failed servers
   foreach $fff (sort keys %ffailed) { 
      $ggg = "$fff\($ffailed{$fff}\)";
      push (@failed_servers,$ggg);
   }

   $server_total_format = format_number($server_total,2,'r',10);
   $server_total_files = format_number($server_total_files,2,'r',12);
   $number_of_tapes_used = sprintf "%4.0f",$number_of_tapes_used;
   $number_of_tapes= $#tape_pool;
   $val = sprintf "%10s",$server;
   print TMPFILE "                                     ==========  ============\n";
   print TMPFILE "                     $number_of_tapes_used Tapes -->  $server_total_format  $server_total_files\n\n";
   print TMPPETE "                     $number_of_tapes_used Tapes -->  $server_total_format  $server_total_files\n\n";
   $weekend_total += $server_total;
   
   print  TMPFILE     "\n    Jukebox Name   Tape Type   Tapes Used    Tapes Free    Free (TB)\n";
   print  TMPFILE     "    ------------   ---------   ----------    ----------    ---------\n";
   foreach $val (sort (keys %jukeboxes)) {
     $number_of_tapes = $jukeboxes{$val};
     $number_of_tapes = sprintf "%7.0f",$number_of_tapes;
     $jukebox_f =sprintf"%-12s",$val;
     $tape_type='Virtual ';
     $factor   =0.07;
     if ($val =~ /ADIC/) {
        $tape_type='Physical';
        # Determine the amount of space available based to tape type
        $factor=0.8;
        if ($jukebox_f =~ /LTO5/) {$factor=2.44};
     }
     print TMPFILE "    $jukebox_f    $tape_type  $number_of_tapes";
     $number_of_tapes = `/usr/sbin/mminfo  -s $server -r volume -q "!full,written<20GB,location=$val" | /usr/bin/wc -l`;
     $number_of_tapes = sprintf "%7.0f",$number_of_tapes;
     print TMPFILE "        $number_of_tapes";
     $space_available = $number_of_tapes*$factor;
     $space_available = sprintf "%7.2f",$space_available;
     print TMPFILE "        $space_available\n";

   }

   $number_of_clients= `/usr/sbin/mminfo -s $server -r 'client' -q "level=full,savetime>last friday 23:00" 2>&1 | /usr/bin/uniq |/usr/bin/wc -l`;
   $number_of_clients = sprintf "%6.0f",$computed_number_of_clients;
   print TMPFILE "\n     Total number of clients backed up on server last night =$number_of_clients\n";
   print TMPPETE "\n     Total number of clients backed up on server last night =$number_of_clients\n";
   
   ($number_of_std_licenses,$number_of_std_licenses_used,$number_of_std_licenses_remaining,$number_of_vir_licenses,$number_of_vir_licenses_used,$number_of_vir_licenses_remaining) = &licenses($server);
   $number_of_licenses= sprintf "%6.0f",$number_of_std_licenses;
   $number_of_licenses_used= sprintf "%6.0f",$number_of_std_licenses_used;
   $number_of_licenses_remaining= sprintf "%6.0f",$number_of_std_licenses_remaining;
   print TMPFILE "            Total Number of Standard Legato Client licenses =$number_of_licenses\n";
   print TMPFILE "       Total Number of Standard Legato Client licenses used =$number_of_licenses_used\n";
   print TMPFILE "       Total Number of Standard Legato Client licenses free =$number_of_licenses_remaining\n";
   print TMPPETE "            Total Number of Standard Legato Client licenses =$number_of_licenses\n";
   print TMPPETE "       Total Number of Standard Legato Client licenses used =$number_of_licenses_used\n";
   print TMPPETE "       Total Number of Standard Legato Client licenses free =$number_of_licenses_remaining\n";
   $number_of_licenses= sprintf "%6.0f",$number_of_vir_licenses;
   $number_of_licenses_used= sprintf "%6.0f",$number_of_vir_licenses_used;
   $number_of_licenses_remaining= sprintf "%6.0f",$number_of_vir_licenses_remaining;
   print TMPFILE "             Total Number of Virtual Legato Client licenses =$number_of_licenses\n";
   print TMPFILE "        Total Number of Virtual Legato Client licenses used =$number_of_licenses_used\n";
   print TMPFILE "        Total Number of Virtual Legato Client licenses free =$number_of_licenses_remaining\n";
   print TMPPETE "             Total Number of Virtual Legato Client licenses =$number_of_licenses\n";
   print TMPPETE "        Total Number of Virtual Legato Client licenses used =$number_of_licenses_used\n";
   print TMPPETE "        Total Number of Virtual Legato Client licenses free =$number_of_licenses_remaining\n";
   $server_total_suspect = format_number($server_total_suspect,0,'r',6);
   print TMPFILE "                                        Suspect Filesystems =$server_total_suspect\n";
   print TMPPETE "                                        Suspect Filesystems =$server_total_suspect\n";
   $server_total_filesystems = format_number($server_total_filesystems,0,'r',6);
   print TMPFILE "                                         Total File Systems =$server_total_filesystems\n";
   print TMPPETE "                                         Total File Systems =$server_total_filesystems\n";
   #if ($BKPROXY1_FAILS > 3) { 
   #    $bf1 = format_number($BKPROXY1_FAILS,0,'r',6);
   #    print TMPFILE "\n\t***********************************************************\n";
   #    print TMPFILE "\t****ERROR: BKPROXY1 is hung or the Networker server is down\n"; 
   #    print TMPFILE "\t****ERROR: BKPROXY1 needs to be rebooted\n";
   #    print TMPFILE "\t***********************************************************\n";
   #    print TMPPETE "\n\t***********************************************************\n";
   #    print TMPPETE "\t****ERROR: PROXY1 is hung or the Networker server is down\n"; 
   #    print TMPPETE "\t****ERROR: PROXY1 needs to be rebooted\n";
   #    print TMPPETE "\t***********************************************************\n";
   #}
   #if ($BKPROXY2_FAILS > 3) { 
   #    $bf1 = format_number($BKPROXY2_FAILS,0,'r',6);
   #    print TMPFILE "\n\t***********************************************************\n";
   #    print TMPFILE "\t****ERROR: BKPROXY2 is hung or the Networker server is down\n";  
   #    print TMPFILE "\t****ERROR: BKPROXY2 needs to be rebooted\n";
   #    print TMPFILE "\t***********************************************************\n";
   #    print TMPPETE "\n\t***********************************************************\n";
   #    print TMPPETE "\t****ERROR: PROXY2 is hung or the Networker server is down\n";  
   #    print TMPPETE "\t****ERROR: PROXY2 needs to be rebooted\n";
   #    print TMPPETE "\t***********************************************************\n";
   #} 

   if (defined @failed_servers) {
       $number_of_failed=$#failed_servers +1;
       print TMPFILE "\n\n          Failed backups for $number_of_failed servers:\n";
       print TMPPETE "\n\n          Failed backups for $number_of_failed servers:\n";
#      foreach $temp (@failed_servers) {
#         $temp =~ s/^\s+//; 
#         my ($pingee,$groupee) = split(/\(/,$temp);
#         $up = "down";
#         # Test to see if machine is up
#         $ping = `/usr/bin/ssh -q $user\@$server "/usr/sbin/ping  $pingee   5" 2>/dev/null`;
#         if ($ping =~ /is alive/) { $up='up'}; 
#         $temp =sprintf"%-37s",$temp;
#         print TMPFILE "             $temp - $up\n";
#      }
       $return = mail_out($server,@failed_servers);
       #print TMPFILE "$return\n";
   }
   if ($detailed == '1') {
      if ( %suspected) {
         print TMPFILE "\n\nSuspect backups for:\n";
         print TMPFILE     "------------------------------------------------------------------------\n";
         $clientsave="shsghdgf";
         foreach $temp (sort(keys %suspected)) {
            ($client,$name,$volume) = split(/\[/,$temp);
            if ($client ne $clientsave) {
               $val        =sprintf"%-20s",$client;
               print TMPFILE "->$val\n";
               $clientsave=$client;
            }
            $val        =sprintf"%-60s",$name;
            print TMPFILE "    $val";
            $val        =sprintf"%8s",$volume;
            print TMPFILE "$val\n";
         }
      }
   }

}
print TMPFILE     "------------------------------------------------------------------------\n";
print TMPPETE     "------------------------------------------------------------------------\n";
$weekend_total = format_number($weekend_total,2,'l',12);
print TMPFILE "\n\nDaily Backup Totals (GB)  $weekend_total\n";
print TMPPETE "\n\nDaily Backup Totals (GB)  $weekend_total\n";
$number_of_files_total = format_number($number_of_files_total,0,'l',12);
print TMPFILE     "Total Number of files $number_of_files_total\n";
print TMPFILE "ENDMAIL\n";
print TMPPETE "ENDMAIL\n";
print FAILMAIL "ENDMAIL\n";
close TMPFILE;
close TMPPETE;
close FAILMAIL;
$return = `/usr/bin/sh  /nsr/local/MorningReports/$date > /dev/null 2>&1`;
$return = `/usr/bin/sh  /nsr/local/MorningReports/Fail$date > /dev/null 2>&1`;
$return = `/usr/bin/sh  /nsr/local/MorningReports/$petedate > /dev/null 2>&1`;
#$return = `/usr/bin/scp -q /nsr/local/MorningReports/$petedate sscmail:/tmp/$date 2>/dev/null`;
#$return = `/usr/bin/ssh -q sscmail /usr/bin/chmod +x /tmp/$date 2>/dev/null`;
#$return = `/usr/bin/ssh -q sscmail /tmp/$date 2>/dev/null`;
#unlink ("/nsr/local/MorningReports/tmp1$date") or die "Can't delete /nsr/local/MorningReports/tmp1$date: $!\n";

sub commify {
     my $text = reverse $_[0];
     $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
     return scalar reverse $text;
}

sub format_number {
   my ($val,$places,$justify,$width) = @_;
   my $text1;
   $text=reverse $val;
   $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
   $val=reverse $text;
   $val =~ s/(\d*\.\d{$places})\d*/$1/;
   $length = length($val);
   if ($justify eq 'l') {
      $start = 0;
   } elsif ($justify eq 'c') {
      $start = int( ($width-$length)/2 );
   } elsif ( $justify eq 'r') {
      $start = $width-$length;
   } else {
      print "Error in formatnumber\n";
  }
   $final = ' ' x $width;
   substr($final,$start,$length)=$val;
   return $final;
}

sub licenses {
   (@server)  = @ARGV;

   (@licenses) = `/usr/sbin/nsrlic -s $server 2>/dev/null`;
   if ($licenses[0] =~ 'no matches found for the license query') {print "Exiting\n";exit};
   $check = '';
   foreach $vals (@licenses) {
       chop $vals;
       next if !defined $vals;
       if ($vals =~ /STANDARD CLIENT LICENSES/) {$check='STD'};
       if ($vals =~ /VIRTUAL CLIENT LICENSES/) {$check='VIR'};
       if ($check =~ /STD/) {
          if ($vals =~ /Available:/) {
             ($number_of_std_licenses = $vals) =~ s/\s+Available:\s+//;
          } elsif ($vals =~ /Used:/) {
             ($number_of_std_licenses_used = $vals) =~ s/\s+Used:\s+//;
          } elsif ($vals =~ /Remaining:/) {
             ($number_of_std_licenses_remaining = $vals) =~ s/\s+Remaining:\s+//;
          }
        } elsif ($check =~ /VIR/) {
          if ($vals =~ /Available:/) {
             ($number_of_vir_licenses = $vals) =~ s/\s+Available:\s+//;
          } elsif ($vals =~ /Used:/) {
             ($number_of_vir_licenses_used = $vals) =~ s/\s+Used:\s+//;
          } elsif ($vals =~ /Remaining:/) {
             ($number_of_vir_licenses_remaining = $vals) =~ s/\s+Remaining:\s+//;
             last;
          }
        }
   }
#    print "SL=$number_of_std_licenses,SLU=$number_of_std_licenses_used,Num=$number_of_std_licenses_remaining,VL=$number_of_vir_licenses,VLU=$number_of_vir_licenses_used,VLR=$number_of_vir_licenses_remaining\n";

   return $number_of_std_licenses,$number_of_std_licenses_used,$number_of_std_licenses_remaining,$number_of_vir_licenses,$number_of_vir_licenses_used,$number_of_vir_licenses_remaining;
}


sub mail_out {
   ($nsr_server,@failed_servers) = @_;
   $site='New Orleans'; 
   if ($nsr_server eq 'sdprodeng') {$site=' San Diego '};
   $dashes = '|-----------------------------------------------------------------------------------------|';
   ($hr) = (localtime($seconds_from_1970))[2];
   $remediation                = '   The Following Servers Require Remediation    ';
   if ($hr > 16) {$remediation = "Today's Backups Failed for the Following Servers"};
   %seen = ();
   undef @uniq;
   foreach $item (@failed_servers) {
      #print "******In mail_out $item\n";
      push (@uniq,$item) unless $seen{$item}++;
   }

   #print "Inside mail out $nsr_server\n";
   open (SUPPORT,"</nsr/local/Emails/data/ServerSupport.txt") or die "Could not open file /nsr/local/Emails/data/ServerSupport.txt\n";
   undef (%mailgroup);
   undef (%backup_type);
   undef (%grouped);
   undef (%failed_groups);
   undef (%running_group);
   foreach $val (<SUPPORT>) {
      next if $val =~ /^\s*$/;
      next if $val =~ /^\s*#/;
      chomp $val;
      my ($server,$tgroup) = split(/,/,$val);
      $server = lc($server);
      $mailgroup{$server} = $tgroup;
   }
   #print "Below support.txt\n";
   $nsrpass = ". type:NSR client'\n'show name\\;backup command\\;action'\n'print"; 
   (@nsradmin) =  `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $server -i -`;
   #(@nsradmin) = `/usr/sbin/nsradmin -s $nsr_server -i /nsr/local/Emails/backup_command.cmd`;
   foreach $val (@nsradmin) {
      next if $val =~ /Current Query Set/;
      next if $val =~ /^\s*$/;
      chomp $val;
      if ($val =~ /name:/) {
         $host = $val;
         $host = lc($host);
         $host =~ s/\s*name: //;
         $host =~ s/\;//;
      } elsif ($val =~ /backup command/) {
         if ($val =~ /nsrvadp/) {
            $backup_type{$host} = '  VADP';
         } else {
            $backup_type{$host} = 'STANDARD';
         }
         #print "Host=$host, Type=$backup_type{$host}\n";
      }
   }

   #$address='NEDCSupport\@navy.mil';
   #$subject='**P/A - (ADMINS) Backup Remediation';
   $signature="Peter Reed\nContractor, aVenture Technologies\n2251 Lakeshore Drive\nSPAWAR Systems Center Atlantic\nNew Orleans Office";

   #print "Building list of servers backed up\n";
   #(@backup_clients)=`/usr/sbin/mminfo -r client -q 'savetime>last week' | /usr/bin/uniq `;
   #foreach $server (@backup_clients) {
   #   chop $server;
   #   $server = lc($server);
   #   #$check{$server} = 1;
   #   if (!defined $mailgroup{$server}) {
   #      print "Server $server has no mail group assigned\n";
   #   }
   #}
   foreach $val (@uniq) {
      $temp = $val;
      $temp =~ s/^\s+//; 
      my ($failed,$groupee) = split(/\(/,$temp);
      $failed =~ s/\s+$//; 
      $failed = lc($failed);
      #Print "Failed=***$failed***by $groupee\n";
      $running_group{$failed} = $groupee;
      if (defined $mailgroup{$failed}) {
         $mgroup = $mailgroup{$failed};
      } else {
         $mgroup = 'None';
         #print "********No mail group assigned for $failed\n";
      }
      # List of client by mail group
      if (defined $grouped{$mgroup}) {
         $grouped{$mgroup} = "$grouped{$mgroup}:$failed";
      } else {
         $grouped{$mgroup} = $failed;
      }
      $failed_groups{$mgroup} = 1;
   }
   undef %failed_prod_servers;
   undef %failed_non_prod_servers;
   foreach $tgroup (sort keys %failed_groups) {
      #print "Mail Group=$tgroup\n";
      (@list_of_failed) = split(/:/, $grouped{$tgroup});
      $ffff = $#list_of_failed + 1;
      print TMPFILE "\n   --------------------------- M A I L  G R O U P:  $tgroup, Failed = $ffff -----------------------------\n";
      print TMPFILE "                       \t    DNS  \t          \t             \t  Backup\n";
      print TMPFILE "         Server        \t   CHECK \t    STATUS\t    PROGRAM  \t   Type \t          BACKUP GROUP     \t Networker Software\n";
      print TMPFILE "   --------------------\t  -------\t    ------\t  -----------\t --------\t    ------------------------\t--------------------\n";
      # print "Above tgroup processing $tgroup, # of servers = $#list_of_failed\n";
      foreach $server (@list_of_failed) {
        $ping = pinger($server);
        if ($ping =~ /up/) {
           $port = testport($server,7937);
        } else {
           $port = 'Client not listening';
        }
        $dns = resolv_name($server);
        $program = check_program($server);
        if (defined $running_group{$server}) {
           if ( ($running_group{$server} =~ /ADHOC/) || ($running_group{$server} =~ /Automated/)) {
           } else {
              if ( lc($running_group{$server}) =~ /prod/) {
                 $failed_prod_servers{$server} = 1;
              } else {
                 $failed_non_prod_servers{$server} = 1;
              }
           }
        }
        $return = build_output($server,$dns,$ping,$port,$backup_type{$server},$running_group{$server},$program,140);
        $ADDRESS="peter.reed.ctr\@navy.mil brian.spragins.ctr\@navy.mil jeffrey.l.rodriguez.ctr\@navy.mil";
        ######################################################Test************************************
        $remedy = 0;
        ######################################################Test************************************
        if ( $remedy == 1 ) { 
           open(REMEDY,">/nsr/local/Emails/$server") or die "Can't open file /nsr/local/MorningReports/$server\n";
           print REMEDY "mailx -s \'Create SR for backup failure of $server\' $ADDRESS<<ENDMAIL\n";
           print REMEDY "Helpdesk,\nPlease create a Service Request for remdiation of backup problems and put in the $tgroup\'s Group\n\n";
           print REMEDY "Customer: Rodriguez, Jeffrey\n\n";
           print REMEDY "Subject: Backup failed for server \"$server\"\n\n";
           print REMEDY "Description:\n\n";
           print REMEDY "\n      Server          \tDNS CHECK  \tSTATUS  \tPROGRAM  \tBackup Type    \tBACKUP GROUP     \tNetworker Software\n";
           print REMEDY "      ------          \t---------  \t------  \t-------  \t-----------  \t----------------    \t------------------\n";
           print REMEDY "   $return\n\n";
           print TMPFILE "   $return";
           print REMEDY "(DETAILS TAB)\n";
           print REMEDY "System: NEW ORLEANS NAVY DATA CENTER (NEDC)\n\n";
           print REMEDY "Component: SUSTAINMENT\n\n";
           $pppp = uc($program);
           print REMEDY "Item: \($pppp\)\n\n";
           print REMEDY "Call Code: Internet\n\n";
           print REMEDY "(ACTIVITY TAB)\n";
	   print REMEDY "Work History: Created SR because of backup failure\n\n";
           print REMEDY "Assigned Group: $tgroup\n";
           print REMEDY "\n\n$signature\n";
           print REMEDY "ENDMAIL\n";
           close REMEDY;
           #$return = `/usr/bin/sh  /nsr/local/Emails/$server 2>&1 /dev/null`;
        }

        print TMPFILE "$return\n";
      }
   }
   $wide = 0;
   $final = ' ' x 130;
   print TMPFILE "\n|-----------------------------------------------------------------------------------------|\n";
   print TMPFILE "|                  THE BELOW LISTS INDICATE SERVERS NOT YET REMEDIATED                    |\n";
   print FAILMAIL "\n|----------------------------------------------------------------------------------------|\n";
   print FAILMAIL "|                  THE BELOW LISTS INDICATE SERVERS NOT YET REMEDIATED                   |\n";
   if (%failed_prod_servers) {
      $number = keys %failed_prod_servers;
      print TMPFILE "$dashes\n";
     print FAILMAIL "$dashes\n";
      print TMPFILE "|                    $remediation                     |\n";
     print FAILMAIL "|                    $remediation                     |\n";
      print TMPFILE "|                      FAILED PRODUCTION SERVERS in $site ($number)                      |\n";
     print FAILMAIL "|                      FAILED PRODUCTION SERVERS in $site ($number)                      |\n";
      print TMPPETE "|                      FAILED PRODUCTION SERVERS in $site ($number)                      |\n";
      print TMPFILE "$dashes\n";
     print FAILMAIL "$dashes\n";
      foreach $val (sort keys %failed_prod_servers) {
         if ($server =~ /sscprodeng/) {print FAILFILE "$val\n"};
         if ($wide > 75) {
             print TMPFILE "$final\n";
             print TMPPETE "$final\n";
             print FAILMAIL "$final\n";
             $wide = 0;
             $final = ' ' x 130;
         } 
         substr($final,$wide,25)=$val;
         $wide+=25;
      }
      if ($final !~ /^\s+$/) {
         print TMPFILE "$final\n";
         print TMPPETE "$final\n";
         print FAILMAIL "$final\n";
      }
   } else {
      print TMPFILE "$dashes\n";
     print FAILMAIL "$dashes\n";
      print TMPFILE "|                          NO FAILED PRODUCTION SERVERS in $site                            |\n";
      print TMPPETE "|                          NO FAILED PRODUCTION SERVERS in $site                            |\n";
     print FAILMAIL "|                          NO FAILED PRODUCTION SERVERS in $site                            |\n";
      print TMPFILE "$dashes\n";
     print FAILMAIL "$dashes\n";
   }
   $wide = 0;
   $final = ' ' x 130;
   # Hash has members
   if (%failed_non_prod_servers) {
      $number = keys %failed_non_prod_servers;
      print TMPFILE "\n$dashes\n";
     print FAILMAIL "\n$dashes\n";
      print TMPFILE "|                     $remediation                    |\n";
     print FAILMAIL "|                     $remediation                    |\n";
      print TMPFILE "|                    FAILED NON-PRODUCTION SERVERS in $site ($number)                    |\n";
      print TMPPETE "|                    FAILED NON-PRODUCTION SERVERS in $site ($number)                    |\n";
     print FAILMAIL "|                    FAILED NON-PRODUCTION SERVERS in $site ($number)                    |\n";
      print TMPFILE "$dashes\n";
     print FAILMAIL "$dashes\n";
      foreach $val (sort keys %failed_non_prod_servers) {
        if ($server =~ /sscprodeng/) {print FAILFILE "$val\n"};
        if ($wide > 75) {
           print TMPFILE "$final\n";
           print TMPPETE "$final\n";
           print FAILMAIL "$final\n";
           $final = ' ' x 130;
           $wide = 0;
        }
        substr($final,$wide,25)=$val;
        $wide += 25;
      }
      if ($final !~ /^\s+$/) {
	print TMPFILE "$final\n";
	print TMPPETE "$final\n";
	print FAILMAIL "$final\n";
      }
   } else {
      print TMPFILE "\n\n$dashes\n";
     print FAILMAIL "\n\n$dashes\n";
      print TMPFILE "--                     NO FAILED NON-PRODUCTION SERVERS in $site                     --\n";
      print TMPPETE "--                     NO FAILED NON-PRODUCTION SERVERS in $site                     --\n";
     print FAILMAIL "--                     NO FAILED NON-PRODUCTION SERVERS in $site                     --\n";
      print TMPFILE "$dashes\n";
     print FAILMAIL "$dashes\n";
   }
   return $return;
}
sub pinger{
   ($pingee) = @_;
   $up = 'down';
   # Test to see if machine is up
   $ping = `/usr/sbin/ping  $pingee   5 2>/dev/null`;
   if ($ping =~ /is alive/) {$up=' up'};
   return $up;
}
sub testport{
   ($host,$port) = @_;
   use IO::Socket;
   $| = 1;  # Flush Buffer immediately
   $socket = IO::Socket::INET->new(PeerAddr => $host, PeerPort =>$port, Timeout => 5);
   if ($socket) {
      $return = "  Client listening";
   } else {
      $return = "Client not listening";
   }
}

sub resolv_name {
    my ($check) = @_;
    $return = "Not in DNS";
    push(@DNS,'192.168.104.240','192.168.104.241','192.168.104.56','192.168.104.57');
    push(@SUF,'sscnola.oob','sscnola.oob','cdc.local','cdc.local');
    my $index =-1;
    foreach $dns (@DNS) {
       $index+=1;
       my (@dum) = `/usr/sbin/nslookup $check.$SUF[$index] $dns`;
       $bc =0;
       foreach $val (@dum) {
         #$val =~ s/\s//g;
         chomp $val;
         if ( $bc == 1 ) {
            if ( $val =~ /Address:/ ) {
               $return = "  In DNS";
               goto RETURN;
            } else {
               print "problem in nslookup\n";
            }
         }
         if ($val =~ /can't find $check/ ) {
            goto RETURN;
         } elsif ($val =~ /Name:/) {
           $bc=1;
         }
       }
    }
    RETURN:
    return $return;
}
sub build_output{
   my ($host,$dns,$ping,$port,$type,$groupee,$program,$width) = @_;
   $final = ' ' x $width;
#"          1         2         3         4         5         6         7         8         9        10        11
#" 12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890
#" --------------------------- M A I L  G R O U P:  $tgroup, Failed = $ffff -----------------------------\n";
#"                         \t  DNS      \t        \t            \t Backup\n";
#"         Server          \t CHECK     \tSTATUS  \t  PROGRAM   \t  Type      \t     BACKUP GROUP       \t Networker Software\n";
#"   --------------------  \t-------    \t------  \t----------- \t--------    \t------------------------\t--------------------\n";
   substr($final,0,20)=$host;
   substr($final,21,1) = "\t";
   substr($final,22,8)=$dns;
   substr($final,31,1) = "\t";
   substr($final,32,6)=$ping;
   substr($final,39,1) = "\t";
   $program = uc($program);
   substr($final,42,10)=uc($program);
   substr($final,53,1) = "\t";
   if (defined $type) {
      substr($final,54,9)=$type;
   }
   substr($final,64,1) = "\t";
   $ggg = $groupee;
   $ggg =~ s/\)//;
   substr($final,65,21)=$ggg;
   substr($final,87,1) = "\t";
   substr($final,88,20)=$port;
   #$final = "$host\t\t$dns\t$ping\t$program\t$type\t$ggg\t\t\t$port";
   return $final;
}

sub check_program {
   my ($host) = @_;
   $program = lc($host);
   if ($server =~ /^c27/) {
      $program =~ s/c27//;
      $program =~ s/cnla.*$//;
      $program =~ s/spsc.*$//;
      $program =~ s/netc.*/NETC/;
   } else {
      $program =~ s/prd.*$//;
      $program =~ s/tst.*$//;
      $program =~ s/db.*$//;
      $program =~ s/app.*$//;
      $program =~ s/cnla.*$//;
      $program =~ s/spsc.*$//;
      if ($program =~ /^ssc/) {$program='CSA';
      } elsif ($program =~ /^sd/) {$program='CSA-U';
      } elsif ($program =~ /^pd2/) {$program='CSA-U';
      } elsif ($program =~ /^ace/) {$program='ACE';
      } elsif ($program =~ /^itc/) {$program='CMS';
      } elsif ($program =~ /^cms/) {$program='CMS';
      } elsif ($program =~ /^mywm/) {$program='ACE';
      } elsif ($program =~ /^nmpbs/) {$program='NMPBS';
      } elsif ($program =~ /^csams/) {$program='CSAMS';
      } elsif ($program =~ /^rhs/) {$program='RHS';
      } elsif ($program =~ /^sem/) {$program='SEMS';
      } elsif ($program =~ /^nola/) {$program='CSA-WINDOWS';
      } elsif ($program =~ /^sanmgmt/) {$program='CSA-WINDOWS';
      } elsif ($program =~ /^uivm/) {$program='CSA-WINDOWS';
      } elsif ($program =~ /^anal/) {$program='CSA-WINDOWS';
      } elsif ($program =~ /^vc/) {$program='CSA-W';
      } elsif ($program =~ /^ssc/) {$program='CSA-NSO';
      } elsif ($program =~ /^nso/) {$program='CSA-NSO';
      } elsif ($program =~ /^lems/) {$program='CSA-NSO';
      } elsif ($program =~ /^sccv/) {$program='CSA-NSO';
      } elsif ($program =~ /^jalis/) {$program='CSA-UNIX';
      } elsif ($program =~ /^coopns/) {$program='CSA-UNIX';
      } elsif ($program =~ /^nrows/) {$program='CSA-UNIX';
      } elsif ($program =~ /^mrrs/) {$program='CSA-UNIX';
      } elsif ($program =~ /^rmmco/) {$program='CSA-UNIX';
      } elsif ($program =~ /^dia/) {$program='CSA-NSO';
      } elsif ($program =~ /^sepm/) {$program='CSA-NSO';
      } elsif ($program =~ /^oem/) {$program='CSA-DBA';
      } elsif ($program =~ /^bkp/) {$program='CSA-BACKUPS';
      } elsif ($program =~ /^ldap/) {$program='CSA-UNIX';
      } elsif ($program =~ /^ns\d/) {$program='CSA-UNIX';
      } elsif ($program =~ /^apache/) {$program='CSA-UNIX';
      } elsif ($program =~ /^prod/) {$program='CSA';
      } elsif ($program =~ /^mgmt/) {$program='CSA';
      } elsif ($program =~ /^monperf\d/) {$program='CSA-SOLARWINDS';
      } elsif ($program =~ /.*-c$/) {$program='CSA-SOLARWINDS';
      } else {
        $program = '????';
      }
      $program = uc($program);
  }
  return $program;
}

