#!/usr/bin/perl -w
$SOURCE      = 'sscprodeng';
$DESTINATION = 'sscprodeng2';

# Build a list of enablers on the new server
$nsrpass = ". type:NSR pool'\n'show name\\;action'\n'print";
(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $DESTINATION -i -`;
foreach $val (@return) {
   chomp $val;
   if ($val =~ /\s+name:/) {
      $val =~ s/^\s+name: //;
      $val =~ s/\;//;
      $dpool{$val} = 1;
   }
}
#foreach $val (sort keys %dpool) {
#   print "pool: $val\n";
#}
#

$nsrpass = ". type:NSR pool'\n'name\\;'\n'print";
(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $SOURCE -i -`;
foreach $val (@return) {
   chomp $val;
   if ($val =~ /\s+name:/) {
      $val =~ s/^\s+name: //;
      $val =~ s/\;//;
      next if defined $dpool{$val}; 
      $spool{$val} = 1;
   }
}
#foreach $val (sort keys %spool) {
#   print "pool: $val\n";
#}

open (NEW_POOL,">new_pool_create_script.sh") or die "Could not create file new_pool_create_script.sh\n";
print NEW_POOL "/usr/bin/cat <<EOF | nsradmin -s $DESTINATION -i - \n";
$count=0;
foreach $val (sort keys %spool) {
   chomp $val;
   print "Val=$val\n";
   if ($count ==10) {exit};
   $nsrpass = ". type:NSR pool\\;name:$val'\n'show'\n'print";
   (@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $SOURCE -i -`;
   foreach $val1 (@return) {
      chomp $val1;
      next if ($val1 =~ /Current query set/);
      next if ($val1 =~ /Will show all attributes/);
      next if ($val1 =~ /NSR pool/);
      if ($val1 =~ /name: /) {$val1=~s/^\s+/\ncreate type: NSR pool\;/};
      print NEW_POOL "$val1\n";
   }
   $count+=1;
}
print NEW_POOL "EOF\n";
