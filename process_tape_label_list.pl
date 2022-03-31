#!/usr/bin/perl -w
# Process Tapes for Labeling
# no "#" tape available for labeling
# one "#" tape being labeled 
# two "#" tape labeled
($datestamp,$labelno) = @ARGV;
$filename = "/home/scriptid/scripts/BACKUPS/LABELING/Label_log\_$datestamp\_$labelno";
open (LOG,">$filename") or die "Could not open log file in Process Tape Label List\n";
print LOG "Filename=$filename\n";
select LOG;
$| = 1;				# Flush Buffers after every write
print LOG "Begin labeling stream $labelno\n";
$time = 0;
my ($volume,$volid);
my ($complete)="123456";

# Use to monitor failed mounts, not enough tape drives available
$stream_errors = 0;

TRYAGAIN:
undef @B;

# This is the file containing the list of volumes
open (TAPE_LIST,"+</home/scriptid/scripts/BACKUPS/LABELING/tape_list_$datestamp") or die "Could not open tape list /home/scriptid/scripts/BACKUPS/LABELING/tape_list_$datestamp in Process Label\n";
# flock(FILEHANDLE,Operation)
#   2 - Exclusive lock
#   8 - Unlock


if  (flock(TAPE_LIST,2)) {			# Exclusive file lock
    # Able to lock file
    # Determine which tape to use,	"#" indicates already used
    $iskip = 0;
    select TAPE_LIST;
    $| = 1;				# Flush Buffers after every write
    while (<TAPE_LIST>) {
       chop $_;

       if ($_ =~ /^\#\#\#/) {
          print LOG "Screwed up and am looping\n";		# Clean up before exit
          flock(TAPE_LIST,8) or die "Can't unlock file $!\n";	# Unlock file
          close TAPE_LIST or die "Can't close file $!\n";		# Close file
          die "Screwed up and am looping\n";
       }

       if ($_ =~ /^\#$complete/) {
          if ($iflag == 1) {
            $_ = "#$_";			# Mark that the tape has been completely copied by adding a second # at beginning of line
            $complete = "123456";
          } else {
            $_ =~ s/^#//;       # Remove the # since it didn't work
          }
       }

       if ($iskip == 0) {  		# Already found a tape to use, continue rewriting file into array @B
          if ($_ !~ /^#/) {		# Didn't find a # sign in the first column
             # Found a tape to process
             ($volume,$server,$alternate,$pool,$slot,$capacity_txt,$jukebox) = split(/,/,$_);	# Server is used to delete volume from correct database
             $_ = "#$_";   		# Tape is being processed, other instances will skip
             $iskip = 1;		# Don't look for more tapes just finish writing the file.
          }
       }
       push (@B,"$_\n");		# Save records to write back out
    }
    # Write out new file and unlock
    seek (TAPE_LIST,0,0) || die "Can't position to beginning of file $!\n";	# Move to beginning
    print TAPE_LIST @B;					# Output modified ARRAY
    flock(TAPE_LIST,8) || die "Can't unlock file $!\n";	# Unlock file
    close TAPE_LIST || die "Can't close file $!\n";		# Close file
    if ($iskip==0) {die "No more tapes to process\n"};
    sleep 5;

    # Begin labeling of tapes
    print LOG "Begin Labeling Volume=$volume\n";
    $return = `/usr/sbin/nsrmm -s $server -d -y -v $volume 2>&1`;
    print LOG "Return from deleting tape $volume, $return";
    if ($! !~ /Illegal seek/) {
       print LOG ", $!\n";
    }elsif ($! =~ /not in the media index/) {
       print LOG "Doesn't require deletion from media index\n";
    } else {
       print LOG "\n";
    }
    # Delete the tape on the remote server that it is being transferred from
    if (defined $alternate) {
       # Delete the tape
       print LOG "/usr/sbin/nsrmm -s $alternate -d -y -v $volume \n";
       $return = `/usr/sbin/nsrmm -s $alternate -d -y -v $volume 2>&1`;
       print LOG "Return from deleting tape $volume on remote server $alternate, $return";
       if ($! !~ /Illegal seek/) {
          print LOG ", $!\n";
       }elsif ($! =~ /not in the media index/) {
          print LOG "Doesn't require deletion from media index\n";
       } else {
          print LOG "\n";
       }
    }
    $iflag = 1;
    RELABEL: print LOG "/usr/sbin/nsrjb  -L -c $capacity_txt -s $server -S $slot -Y -j $jukebox -b $pool $volume\n";
    $return=`/usr/sbin/nsrjb  -L -c $capacity_txt -s $server -S $slot -Y -j $jukebox -b $pool $volume 2>&1`;
    print LOG "Return from labeling tape $volume, $return";
    if ($return =~ /Cannot allocate the /) {
       # Cannot allocate a tape drive to use
       print LOG "Could not allocate a tape drive for tape $volume\n";
       $stream_errors += 1;
       $iflag = 0;
       if ($stream_errors > 5) {
          print LOG "Could not allocate a tape drive after 5 tries (5 minutes) so exiting\n";
          exit;
       }
       sleep 60;
       goto TRYAGAIN;
    }
    # $! - in numeric context, yields the current value of errno
    # $! - in string context, yields the corresponding system error.  
    # errno is the global variable which UNIX returns error numbers to C programs.
    # perl error messages returned in $@.
    if ($! !~ /Illegal seek/) {
       print LOG ", $!\n";
    } else {
       print LOG "\n";
    }
    $complete = $volume;
    if ($return =~ /succeeded/) {
       print LOG "Finished labeling tape $volume in stream $labelno, Return=$return\n";
    } else { 
       print LOG "Couldn't label tape $volume in stream $labelno, Return=$return\n";
       $iflag = 0;
       sleep 10;
    }
   
} else {
    # Couldn't lock file.  Wait and try again
    $time=$time+5;
    if ($time > 60) {die "Could not lock file /home/scriptid/scripts/BACKUPS/LABELING/tape_list_$datestamp  after trying for 60 seconds\n"};
    print LOG "Could not lock file /home/scriptid/scripts/BACKUPS/LABELING/tape_list_$datestamp.  Waiting 5 seconds\n";
    sleep 5;
}
goto TRYAGAIN;
