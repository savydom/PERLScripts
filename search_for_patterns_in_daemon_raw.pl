#!/usr/bin/perl -w
# Utility to process Legato /nsr/logs/daemon.raw style files.
# Anything that can be rendered with nsr_render_log
# 
$date = `date`;
print "Enter a brief problem description (So you can tell what the report is for)\n";
$header=<STDIN>;
chop $header;
print "Enter daemon.raw file to search (Anything that can be viewed with nsr_render_log)\n";
$file = <STDIN>;
chop $file;
print "Enter start time with quotes (Any format that Legato accepts surrounded by quotes)\n";
$start = <STDIN>;
chop $start;
print "Enter primary search string without quotes (basically the field used to grep)\n";
$search = <STDIN>;
print "Enter colate search string, (usually the text before the hostname)\n";
chop $search;
$collate = <STDIN>;
chop $collate;
print "Non blank to create collated_daemon_raw.txt (blank for just screen output, anything else creates the file)\n";
$print = <STDIN>;
chop  $print;
$iflag = 0;
if ($print =~ /\s?/) {
   open (OUTFILE,">collated_daemon_raw.txt") || die "Could not open collated_daemon_raw.txt\n";
   $iflag=1;
}
(@return) = `/usr/bin/nsr_render_log -S $start $file`;
#print "Search=/$collate\s+(\S+)\s+.*/\n";
foreach $val (@return) {
   if ($val =~ /$search/) {
      chop $val;
      #print "Val=$val\n";
      ($sort) = ( $val =~ /$collate\s+(\S+)/);
      #print "Sort=$sort\n";
      if (defined $COUNT{$sort}) {
         $COUNT{$sort} += 1;
      } else {
         $COUNT{$sort} = 1;
      }
   }
}
$amount=0;
if ($iflag == 1) {
   print OUTFILE "Description of problem: $header\n";
   print OUTFILE "                  DATE: $date";
   print OUTFILE "    Raw File Processed: $file\n";
   print OUTFILE "            Start Time: $start\n";
   print OUTFILE "          Search Field: $search\n";
   print OUTFILE "        Collate String: $collate\n\n";
}
print "\n\nRaw File Processed: $file\n";
print "Start Time: $start\n";
print "Search Field: $search\n";
print "Collate String: $collate\n";
foreach $key (sort keys %COUNT) {
   print "Host=$key, Count=$COUNT{$key}\n";
   if ($iflag ==1 ) {print OUTFILE "Host=$key, Count=$COUNT{$key}\n"};
   $amount += 1;
}
if ($iflag ==1 ) {print OUTFILE "\nUnique occurences = $amount\n"};
print "\nUnique occurences = $amount\n";
print "\nOutput File = collated_daemon_raw.txt\n";
#Unable to complete SSL handshake with host c27baerscnla01d.sscnola.oob
