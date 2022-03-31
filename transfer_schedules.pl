#!/usr/bin/perl -w
$SOURCE      = 'sscprodeng';
$DESTINATION = 'sscprodeng2';

# Build a list of enablers on the new server
$nsrpass = ". type:NSR schedule'\n'show name'\n'print";
(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $DESTINATION -i -`;
foreach $val (@return) {
   chomp $val;
   if ($val =~ /\s+name: /) {
      $val =~ s/^\s+name: //;
      $val =~ s/\;//;
      $dschedule{$val} = 1;
   }
}
foreach $val (sort keys %dschedule) {
   print "Schedule: $val\n";
}
print "_____________________________________________________________\n";
$nsrpass = ". type:NSR schedule'\n'show name'\n'print";
(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $SOURCE -i -`;
foreach $val (@return) {
   chomp $val;
   if ($val =~ /\s+name:/) {
      $val =~ s/^\s+name: //;
      $val =~ s/\;//;
      next if defined $dschedule{$val}; 
      $sschedule{$val} = 1;
   }
}
foreach $val (sort keys %sschedule) {
   print "Schedule: $val\n";
}

open (NEW_SCHEDULE,">new_schedule_create_script.sh") or die "Could not create file new_schedule_create_script.sh\n";
print NEW_SCHEDULE "/usr/bin/cat <<EOF | nsradmin -s $DESTINATION -i - \n";
$count=0;
foreach $val (sort keys %sschedule) {
   chomp $val;
   print "Val=$val\n";
   if ($count ==10) {exit};
   #$val =~ s/\"//g;
   $nsrpass = ". type:NSR schedule\\;name:$val'\n'show'\n'print";
   (@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $SOURCE -i -`;
   foreach $val1 (@return) {
      chomp $val1;
      next if ($val1 =~ /Current query set/);
      next if ($val1 =~ /Will show all attributes/);
      next if ($val1 =~ /NSR schedule/);
      if ($val1 =~ /name: /) {$val1=~s/^\s+/\ncreate type: NSR schedule\;/};
      print NEW_SCHEDULE "$val1\n";
   }
   $count+=1;
}
print NEW_SCHEDULE "EOF\n";
