#!/usr/bin/perl -w
# Process Clone List
($datestamp,$cloneno) = @ARGV;
$logfile="/home/scriptid/scripts/BACKUPS/CLONING/clone_log\_$datestamp" . "_$cloneno";
#print "logfile name=$logfile\n";
open (LOG,">>$logfile") or die "Could not open log file in Process Clone\n";
select LOG;
$| = 1;				# Flush Buffers after every write
print LOG "Begin cloning number $cloneno\n";
$time = 0;
my ($volume,$volid);
my ($complete)="123456";
TRYAGAIN:
undef @B;
print LOG "Clone List File Name /nsr/Cloning/clone_list\_$datestamp\_$cloneno\n";
open (CLONE,"+</home/scriptid/scripts/BACKUPS/CLONING/clone_list_$datestamp") or die "Could not open volume list in Process Clone\n";
if  (flock(CLONE,2)) {			# Exclusive file lock
    # Determine which client to process,	'#' indicates already used
    $iskip = 0;
    select CLONE;
    $| = 1;				# Flush Buffers after every write
    while (<CLONE>) {
       chop $_;
       #print LOG "Volume read from file $_\n";

       if ($_ =~ /^\#\#\#/) {
          print LOG "Screwed up and am looping\n";		# Clean up before exit
          flock(CLONE,8) or die "Can't unlock file $!\n";	# Unlock file
          close CLONE or die "Can't close file $!\n";		# Close file
          die "Screwed up and am looping\n";
       }

       if ($_ =~ /^\#$complete/) {
          $_ = "#$_";			# Mark that the client has been completely copied
          $complete = "123456";
       };

       if ($iskip == 0) {  		# Already found a volume to use, continue rewriting file into array @B
          if ($_ !~ /^#/) {
             # Found a client to process
             ($client,@goodssid)  = split(/:/,$_);
             $_ = "#$_";   		# Tape is being processed, other instances will skip
             $iskip = 1;		# Don't look for more volumes just finish writing the file.
          }
       }
       push (@B,"$_\n");		# Save records to write back out
    }
    # Write out new file and unlock
    seek (CLONE,0,0) || die "Can't position to beginning of file $!\n";	# Move to beginning
    print CLONE @B;					# Output modified ARRAY
    flock(CLONE,8) || die "Can't unlock file $!\n";	# Unlock file
    close CLONE || die "Can't close file $!\n";		# Close file
    if ($iskip==0) {die "No more volumes to process\n"};
    sleep 5;
    $return = 99;

    # Begin cloning of AFTD by client
    # Make sure that it is the start of a saveset(pssid), and that there is only one copy
    # Sort by volume,filesystem,time
    #  Error Message no matches found for the query
    print LOG "Begin Cloning  client $client in session $cloneno\n";
    $return = `/usr/sbin/nsrclone -v -b 'AFTDClone' -y year -w year -S @goodssid 2>&1`;
    print LOG "Return from nsrclone $return\n";
} else {
    # Couldn't lock file.  Wait and try again
    $time=$time+5;
    if ($time > 60) {die "Could not lock file /nsr/Cloning/clone_list\_$datestamp\_$cloneno after trying for 60 seconds\n"};
    print LOG "Could not lock file /nsr/Cloning/clone_list\_$datestamp\_$cloneno.  Waiting 5 seconds\n";
    sleep 5;
}
goto TRYAGAIN;
