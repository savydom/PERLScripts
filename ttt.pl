#!/usr/bin/perl -w 
$line="   2: -*                                                UN7000   -";
$line1="   2: -*                                                UN7000   -";
#($slot) = ($line =~ /^\s+(\d+)\:\s+\-\*\s+\S+/);
($slot) = ($line =~ /^\s+(\d+)\:/);
print "Slot=$slot\n";
($blank_name) = ($line1 =~ /^\s+\S+\:\s+\-\*\s+(\S+)/);
print "Blank=$blank_name\n";
exit;
$volume='UN7000';
$jukebox='ADIC_LTO5_2';
$slot = which_slot($volume,$jukebox);
print "Slot=$slot\n";
sub which_slot {
   ($volume,$jukebox) = @_;
   print "*********** In which_slot /usr/sbin/nsrjb  -C -j $jukebox $volume\n";
   (@save_juke) = `/usr/sbin/nsrjb  -C -j $jukebox`;
   foreach $_ (@save_juke) {
     #print "return from nsrjb $_";
     if ($_ =~ /^\n/) {next};
     if ($_ =~ /Jukebox/) {next};
     if ($_ =~ /slot/) {next};
     chomp $_;
     #print "return from nsrjb $_\n";
     if ($_ =~ /$volume/ ) {
        print "In which_slot line=$_\n";
        ($slot) = ($_ =~ /^s+(\d+)\:/);
        print "In which_slot slot=$slot\n";
        goto RET;
     }
   }
RET:
   $return = $slot;
}

