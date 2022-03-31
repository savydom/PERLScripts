#!/usr/bin/perl -w

$group = 'Automated-PROD-Reruns';
(@client) = `/bin/cat missed_full_prod_weekend_backups.out`;
@return = update_group($group,@client);

$group = 'Automated-NON-PROD-Reruns';
(@client) = `/bin/cat missed_full_non_prod_weekend_backups.out`;
@return = update_group($group,@client);

sub update_group {
    my ($group,@clients) = @_;
    foreach $clnt (@clients) {
      chomp $clnt;
      print "Client=$clnt\n";
      # Create clients in $group and INDEX ignoring the current group
      $val =  ". type: NSR client\\;name:$clnt'\n'append group:$group'\n'";
      (@return) = `/usr/bin/echo $val | /usr/sbin/nsradmin -i - `;
      foreach $vvv (@return) {
         print "INFO: $vvv\n";
      }
    }
}
