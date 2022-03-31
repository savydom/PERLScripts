#!/usr/bin/perl -w
$date =time;
# Run for 23.9 hours
$finish = 23.9 * 3600 + $date;
TOP:
(@return) = `/usr/sbin/nsradmin -i /nsr/local/nsradmin_tape_perf.txt`;
#Current query set
#Dynamic display option turned on
#
#Display options:
#        Dynamic: On;
#        Hidden: Off;
#        Raw I18N: Off;
#        Resource ID: Off;
#        Regexp: Off;
#                        name: /dev/rmt/506cbn;
#                     message: "writing, done ";
#
#                        name: /dev/rmt/507cbn;
#                     message: Eject operation in progress;
#
#                        name: "rd=sscustno1:/dev/rmt/508cbn";
#                     message: "writing at 2751 KB/s, 21 GB, 4 sessions";
#
#                        name: "rd=sscustno1:/dev/rmt/509cbn";
#                     message: "writing, 35 GB";
#
#                        name: /dev/rmt/505cbn;
#                     message: read only;
#
#                        name: "rd=sscustno1:/dev/rmt/312cbn";
#                     message: " ";
$lto3=0;
$lto5=0;
$aftd=0;
$total=0;
$session_total=0;
#undef %speed;
$date =time;
($sec,$min,$hr,$mday,$mon,$yr,$wday) = (localtime($date))[0,1,2,3,4,5,6];
++$mon;
$yr = $yr+1900;
$thisday= (Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$wday];

# Create the output file
$mon = sprintf("%02d",$mon);
$mday= sprintf("%02d",$mday);
$sec = sprintf("%02d",$sec);
$min = sprintf("%02d",$min);
$hr  = sprintf("%02d",$hr);
$prtdate="$mon/$mday/$yr $thisday $hr:$min:$sec";

foreach $val (@return) {
   chomp $val;
   #print "Val=$val\n";
   if ($val =~ /\s+name: /) {
     # Found a device
     # only care about the device name
     if ($val !~ /rmt/) {
        ($device) = ($val =~ /.*name\: \"?(.*)\"?\;/);
     } else {
        ($device) = ($val =~ /.*\/dev\/rmt\/(\d+)cbn\"?\;/);
     } 
     #print "***device=$device\n";
   } elsif ($val =~ /\s+message: /) {

     if ($val =~ /writing at/) {

       #($tapedrive,$speed,$units,$amount,$aunits,$sessions) = ($val =~ /^.*\/dev\/rmt\/(\d\d\d\D\D\D)\(J\).*writing at (\d\d) (\D+)\/s (\d+) (\D\D),\s+(\d+) sessions$/);
       #Val=                     message: "10:writing at 81 MB/s, 678 GB, 19 sessions";
       $speed=$units=$amount=$aunits=$sessions=0;
       #if ($device =~ /508/) {print "Val=$val\n"};
       ($speed,$units,$amount,$aunits,$sessions) = ($val =~ /\"\d*\:?writing at (\d+) (\D\D)\/s, (\d+) (\D\D)(.*)\"\;/);
       #if ($device =~ /508/) {print "$speed,$units,$amount,$aunits,$sessions\n"};
       ($sessions) =~ s/, //;
       ($sessions) =~ s/ sessions//;
       if ($sessions !~ /[0-9]+/) { 
          if ($speed > 0) {
             $sessions = 1;
          } else {
             $sessions=0;
          }
       }
       if (defined $device) {
          print "\t$device,S:$speed,$units,T:$amount,$aunits,\#$sessions\n";
          if ($units =~ /KB/) {$speed = $speed/1000};
          if ($device =~ /AFTD/ || ($device =~ /dsk/) ) {
             $aftd+=$speed;
          } else {
             if ($device < 400) {$lto3+=$speed};
             if ($device > 400) {$lto5+=$speed};
          }
          $session_total = $session_total + $sessions;
       }
     }
   }
}
$total = $lto3+$lto5;

#print "$prtdate, LTO3=$lto3, LTO5=$lto5, Total=$total\n";
print "$prtdate, #=$session_total, LTO5=$lto5, AFTD=$aftd\n";
sleep 10;
if ($date < $finish) {goto TOP};
