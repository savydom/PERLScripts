#!/usr/bin/perl -w
$SOURCE='sscprodeng';
(@return) = `/usr/bin/cat /home/scriptid/scripts/BACKUPS/NewAuthCodes.txt`;
foreach $val (@return) {
   chomp $val;
   next if $val =~ /^#/;
   next if $val !~ /FailOver/;
   #print "Val=$val\n";
   my ($enabler,$authcode) = ($val =~ /^.*\(FailOver Codes\) (.*)\: failovercode\:(.*)$/);
   print "Enabler=$enabler, Authcode=$authcode\n";
   #$enabler =~ s/://;
   #$authcode =~ s/authcode://;
   $nsrpass = ". type:NSR license\\;enabler code:$enabler'\n'update auth code:$authcode";
   print "NSRPASS=$nsrpass\n";
   (@return2) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $SOURCE -i -`;
   print "@return2\n";
}
