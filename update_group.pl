#!/usr/bin/perl -w
$client = 'sscut1016';
$group = 'AFTD Test';
@return = update_group($group,$client);

sub update_group {
    my ($group,@clients) = @_;
    foreach $clnt (@clients) {
      # Create clients in $group and INDEX ignoring the current group
      $val =  ". type: NSR client\\;name:$clnt'\n'update group:INDEX, $group'\n'";
      (@return) = `/usr/bin/echo $val | /usr/sbin/nsradmin -i - `;
      foreach $vvv (@return) {
         print "INFO: $vvv\n";
      }
    }
}
