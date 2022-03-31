#!/usr/bin/perl -w
$SOURCE      = 'sscprodeng';
$DESTINATION = 'sscprodeng2';

# Build a list of enablers on the new server
$nsrpass = ". type:NSR license'\n'show enabler code\\;action'\n'print";
(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $DESTINATION -i -`;
foreach $val (@return) {
   chomp $val;
   if ($val =~ /\s+enabler code:/) {
      $val =~ s/^\s+enabler: //;
      $val =~ s/\;//;
      $denabler{$val} = 1;
   }
}
#foreach $val (sort keys %denabler) {
#   print "Enabler: $val\n";
#}

$nsrpass = ". type:NSR license'\n'show enabler code\\;action'\n'print";
(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $SOURCE -i -`;
open (NEW_ENABLER,">new_enabler_create_script.sh") or die "Could not create file new_enabler_create_script.sh\n";
print NEW_ENABLER "/usr/bin/cat <<EOF | nsradmin -s $DESTINATION -i - \n";
foreach $val (@return) {
   chomp $val;
   if ($val =~ /\s+enabler code:/) {
      $val =~ s/^\s+enabler: //;
      $val =~ s/\;//;
      next if defined $denabler{$val};
      print NEW_ENABLER "create type: NSR license\;$val\;\n";
      print NEW_ENABLER "            auth code: GRACE\n\n";
   }
}
print NEW_ENABLER "EOF\n";
