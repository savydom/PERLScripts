#!/usr/bin/perl -w
$grp = 'Automated-NON-PROD-VADP-Reruns';
$return =  remove_clients_from_group($grp);
sub remove_clients_from_group {
    $val1 =  ". type: NSR client\\;group:$grp'\n'show name\\;group'\n'print"; 
    (@return) = `/usr/bin/echo $val1 | /usr/sbin/nsradmin -i - `;
    $group = '';

    foreach $val (@return) {
      chomp $val;
      $val =~ s/^\s*//;  # Take off leading spaces
      $val =~ s/\;//;    # Take off trailing semi
      next if $val =~ /Current query set/;
      if ($val =~ /name:/) {
         if (defined $client) {
            if ($group =~ /^$grp/) {
               $group =~ s/$grp, //;
            } else {
               $group =~ s/, $grp//;
            }
            $val1 =  ". type: NSR client\\;name:$client'\n'update group:$group";
            (@return1) = `/usr/bin/echo $val1 | /usr/sbin/nsradmin -i - `;
         }
         ($client) = ($val =~ /name: (\S+)$/); 
      } elsif ($val =~ /group/) {
         ($val) =~ s/group: //; 
         $group = $val;
      } else  {
         $group = "$group$val";
      }
    }
    if ($group =~ /^$grp/) {
       $group =~ s/$grp, //;
    } else {
       $group =~ s/, $grp//;
    }
    $val1 =  ". type: NSR client\\;name:$client'\n'update group:$group";
    (@return1) = `/usr/bin/echo $val1 | /usr/sbin/nsradmin -i - `;
}
