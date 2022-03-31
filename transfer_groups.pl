#!/usr/bin/perl -w
$SOURCE      = 'sscprodeng';
$DESTINATION = 'sscprodeng2';

# Build a list of enablers on the new server
$nsrpass = ". type:NSR group'\n'show name\\;action'\n'print";
(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $DESTINATION -i -`;
foreach $val (@return) {
   chomp $val;
   if ($val =~ /\s+name: /) {
      $val =~ s/^\s+name: //;
      $val =~ s/\;//;
      $dgroup{$val} = 1;
   }
}
foreach $val (sort keys %dgroup) {
   if ($val =~ /Transqa/) {print "Group: $val\n"};
}


$nsrpass = ". type:NSR group'\n'name\\;'\n'print";
(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $SOURCE -i -`;
foreach $val (@return) {
   chomp $val;
   if ($val =~ /\s+name: /) {
      $val =~ s/^\s+name: //;
      $val =~ s/\;//;
      next if $val =~ /^sscprodeng$/;
      next if $val =~ /^sscustno1$/;
      print "Val=---$val---\n";
      next if defined $dgroup{"$val"}; 
      $sgroup{$val} = 1;
   }
}
print "________________________________________________\n";
foreach $val (sort keys %sgroup) {
   if ($val =~ /Transqa/) {print "Group: $val\n"};
}
exit;
open (NEW_GROUP,">new_group_create_script.sh") or die "Could not create file new_group_create_script.sh\n";
print NEW_GROUP "/usr/bin/cat <<EOF | nsradmin -s $DESTINATION -i - \n";
$count=0;
foreach $val (sort keys %sgroup) {
   chomp $val;
   print "Val=$val\n";
   if ($count ==10) {exit};
   $nsrpass = ". type:NSR group\\;name:$val'\n'show'\n'print";
   (@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $SOURCE -i -`;
   foreach $val1 (@return) {
      chomp $val1;
      next if ($val1 =~ /Current query set/);
      next if ($val1 =~ /Will show all attributes/);
      next if ($val1 =~ /NSR group/);
      if ($val1 =~ /name: /) {$val1=~s/^\s+/\ncreate type: NSR group\;/};
      print NEW_GROUP "$val1\n";
   }
   $count+=1;
}
print NEW_GROUP "EOF\n";
