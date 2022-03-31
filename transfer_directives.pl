#!/usr/bin/perl -w
$SOURCE      = 'sscprodeng';
$DESTINATION = 'sscprodeng2';

# Build a list of enablers on the new server
$nsrpass = ". type:NSR directive'\n'show name\\;action'\n'print";
(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $DESTINATION -i -`;
foreach $val (@return) {
   chomp $val;
   if ($val =~ /\s+name:/) {
      $val =~ s/^\s+name: //;
      $val =~ s/\;//;
      $ddirective{$val} = 1;
   }
}
#foreach $val (sort keys %ddirective) {
#   print "Directive: $val\n";
#}
#

$nsrpass = ". type:NSR directive'\n'name\\;action'\n'print";
(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $SOURCE -i -`;
foreach $val (@return) {
   chomp $val;
   if ($val =~ /\s+name:/) {
      $val =~ s/^\s+name: //;
      $val =~ s/\;//;
      next if defined $ddirective{$val}; 
      $sdirective{$val} = 1;
   }
}
#foreach $val (sort keys %sdirective) {
#   print "Directive: $val\n";
#}

open (NEW_DIRECTIVE,">new_directive_create_script.sh") or die "Could not create file new_directive_create_script.sh\n";
print NEW_DIRECTIVE "/usr/bin/cat <<EOF | nsradmin -s $DESTINATION -i - \n";
$count=0;
foreach $val (sort keys %sdirective) {
   chomp $val;
   print "Val=$val\n";
   if ($count ==10) {exit};
   $nsrpass = ". type:NSR directive\\;name:$val'\n'show'\n'print";
   (@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $SOURCE -i -`;
   foreach $val1 (@return) {
      chomp $val1;
      next if ($val1 =~ /Current query set/);
      next if ($val1 =~ /Will show all attributes/);
      next if ($val1 =~ /NSR directive/);
      if ($val1 =~ /name: /) {$val1=~s/^\s+/\ncreate type: NSR directive\;/};
      print NEW_DIRECTIVE "$val1\n";
   }
   $count +=1;
}
print NEW_DIRECTIVE "EOF\n";
