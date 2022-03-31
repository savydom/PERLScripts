#!/usr/bin/perl -w
$SOURCE      = 'sscprodeng';
$DESTINATION = 'sscprodeng2';

# Build a list of enablers on the new server
$nsrpass = ". type:NSR label'\n'show name\\;action'\n'print";
(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $DESTINATION -i -`;
foreach $val (@return) {
   chomp $val;
   if ($val =~ /\s+name:/) {
      $val =~ s/^\s+name: //;
      $val =~ s/\;//;
      $dlabel{$val} = 1;
   }
}
#foreach $val (sort keys %dlabel) {
#   print "label: $val\n";
#}
#

$nsrpass = ". type:NSR label'\n'name\\;'\n'print";
(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $SOURCE -i -`;
foreach $val (@return) {
   chomp $val;
   if ($val =~ /\s+name:/) {
      $val =~ s/^\s+name: //;
      $val =~ s/\;//;
      next if defined $dlabel{$val}; 
      $slabel{$val} = 1;
   }
}
#foreach $val (sort keys %slabel) {
#   print "label: $val\n";
#}

open (NEW_LABEL,">new_label_create_script.sh") or die "Could not create file new_label_create_script.sh\n";
print NEW_LABEL "/usr/bin/cat <<EOF | nsradmin -s $DESTINATION -i - \n";
$count=0;
foreach $val (sort keys %slabel) {
   chomp $val;
   print "Val=$val\n";
   if ($count ==10) {exit};
   $nsrpass = ". type:NSR label\\;name:$val'\n'show'\n'print";
   (@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $SOURCE -i -`;
   foreach $val1 (@return) {
      chomp $val1;
      next if ($val1 =~ /Current query set/);
      next if ($val1 =~ /Will show all attributes/);
      next if ($val1 =~ /NSR label/);
      if ($val1 =~ /name: /) {$val1=~s/^\s+/\ncreate type: NSR label\;/};
      print NEW_LABEL "$val1\n";
   }
   $count+=1;
}
print NEW_LABEL "EOF\n";
